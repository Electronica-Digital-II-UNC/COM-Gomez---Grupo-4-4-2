; ==============================================================================
; ASIGNACIONES:
;   RB1: Pulsador de avance (con pull-up)
;   RC0-RC5: Segmentos A-F (Displays Cátodo Común)
;   RA0: Segmento G
;   RA1: Punto decimal (dp) - Apagado
;   RA2: Selector Unidades (Transistor NPN)
;   RA3: Selector Decenas (Transistor NPN)
;   RD0-RD7: Banco de 8 LEDs binarios
; ==============================================================================

    LIST P=16F887
    #INCLUDE <P16F887.INC>

    __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF

    CBLOCK 0x20
        CONTADOR            ; Guarda el numero de 0 a 99
        UNIDADES            ; BCD Unidades
        DECENAS             ; BCD Decenas
        AUX                 ; Auxiliar para conversion
        REB                 ; Contador para antirrebote
        D1, D2              ; Variables para demora
        PORTA_SHADOW        ; Sombra para RA0-RA3
        PATRON              ; Auxiliar para guardar el dato de la tabla
    ENDC

    ORG 0x0000
    GOTO INICIO

; =========================================
; TABLA PARA LOS DISPLAYS DE 7 SEGMENTOS
; Bits 0-5: Segmentos A-F | Bit 6: Segmento G | Bit 7: dp
; =========================================
    ORG 0x0300
TABLA:
    MOVWF PATRON        ; 1. Guardamos el número original (0-9) para no perderlo
    MOVLW HIGH TABLA    ; 2. W se sobrescribe con 0x03 (Parte alta de la memoria)
    MOVWF PCLATH        ; 3. Preparamos el contador de programa
    MOVF PATRON, W      ; 4. ¡Recuperamos el número original en W!
    ADDWF PCL, F        ; 5. Ahora sí, el salto se hace correctamente
    RETLW b'00111111'   ; 0
    RETLW b'00000110'   ; 1
    RETLW b'01011011'   ; 2
    RETLW b'01001111'   ; 3
    RETLW b'01100110'   ; 4
    RETLW b'01101101'   ; 5
    RETLW b'01111101'   ; 6
    RETLW b'00000111'   ; 7
    RETLW b'01111111'   ; 8
    RETLW b'01100111'   ; 9

INICIO:
    BANKSEL ANSEL
    CLRF ANSEL
    CLRF ANSELH

    ; Configurar entradas y salidas
    BANKSEL TRISC
    BCF TRISC, 0
    BCF TRISC, 1
    BCF TRISC, 2
    BCF TRISC, 3
    BCF TRISC, 4
    BCF TRISC, 5        ; RC0-RC5 (Segmentos A-F) como salidas

    BANKSEL TRISA
    BCF TRISA, 0        ; RA0 (Segmento G) como salida
    BCF TRISA, 1        ; RA1 (DP) como salida
    BCF TRISA, 2        ; RA2 (Transistor NPN Unidades) como salida
    BCF TRISA, 3        ; RA3 (Transistor NPN Decenas) como salida

    BANKSEL TRISD
    CLRF TRISD          ; RD0-RD7 como salidas (LEDs binarios)

    BANKSEL TRISB
    BSF TRISB, 1        ; RB1 (Pulsador) como entrada
    
    ; Activar Pull-up en PORTB
    BANKSEL OPTION_REG
    BCF OPTION_REG, NOT_RBPU
    BANKSEL WPUB
    BSF WPUB, 1

    ; Estado inicial
    BANKSEL PORTA
    CLRF PORTA          ; Apagar transistores y segmento G
    CLRF PORTC          ; Apagar segmentos A-F
    CLRF PORTD          ; Apagar LEDs binarios
    CLRF CONTADOR
    CLRF REB
    CALL CONVERTIR

; =========================================
; BUCLE PRINCIPAL (No bloqueante)
; =========================================
PRINCIPAL:
    CALL MULTIPLEXADO   ; Mantener los displays encendidos
    CALL LEER_BOTON     ; Revisar si se pulsa RB1
    GOTO PRINCIPAL

; =========================================
; RUTINA DE MULTIPLEXADO 
; =========================================
MULTIPLEXADO:
    ; --- BLANKING ---
    BANKSEL PORTA
    CLRF PORTA
    CLRF PORTC

    ; --- MOSTRAR UNIDADES ---
    BANKSEL UNIDADES
    MOVF UNIDADES, W
    CALL TABLA
    MOVWF PATRON

    ; Enviar segmentos A-F al PORTC
    MOVF PATRON, W
    ANDLW b'00111111'
    BANKSEL PORTC
    MOVWF PORTC

    ; Seleccionar transistor NPN Unidades (RA2=1) y segmento G (RA0)
    CLRF PORTA_SHADOW
    BSF PORTA_SHADOW, 2
    BTFSC PATRON, 6
    BSF PORTA_SHADOW, 0
    
    BANKSEL PORTA
    MOVF PORTA_SHADOW, W
    MOVWF PORTA
    
    CALL DEMORA_MUX

    ; --- BLANKING ---
    BANKSEL PORTA
    CLRF PORTA
    CLRF PORTC

    ; --- MOSTRAR DECENAS ---
    BANKSEL DECENAS
    MOVF DECENAS, W
    CALL TABLA
    MOVWF PATRON

    MOVF PATRON, W
    ANDLW b'00111111'
    BANKSEL PORTC
    MOVWF PORTC

    ; Seleccionar transistor NPN Decenas (RA3=1) y segmento G (RA0)
    CLRF PORTA_SHADOW
    BSF PORTA_SHADOW, 3
    BTFSC PATRON, 6
    BSF PORTA_SHADOW, 0
    
    BANKSEL PORTA
    MOVF PORTA_SHADOW, W
    MOVWF PORTA

    CALL DEMORA_MUX
    RETURN

; =========================================
; ANTIRREBOTE Y BOTÓN
; =========================================
LEER_BOTON:
    BANKSEL PORTB
    BTFSC PORTB, 1      ; ¿Botón presionado en 0?
    GOTO BOTON_SUELTO

BOTON_PRESIONADO:
    BANKSEL REB
    INCF REB, F         ; Suma un ciclo de lectura
    MOVLW d'3'          ; Espera ~3 ciclos antes de sumar
    XORWF REB, W
    BTFSS STATUS, Z
    RETURN

    ; Si el botón se estabilizó:
    CALL SUMAR
    MOVLW d'3'          ; Bloquea en 3 para no sumar en ráfaga
    MOVWF REB
    RETURN

BOTON_SUELTO:
    BANKSEL REB
    CLRF REB
    RETURN

; =========================================
; INCREMENTAR Y MOSTRAR BINARIO
; =========================================
SUMAR:
    BANKSEL CONTADOR
    INCF CONTADOR, F
    MOVLW d'100'
    SUBWF CONTADOR, W
    BTFSC STATUS, Z
    CLRF CONTADOR

    MOVF CONTADOR, W
    BANKSEL PORTD
    MOVWF PORTD         ; Actualiza los 8 LEDs binarios
    CALL CONVERTIR
    RETURN

; =========================================
; CONVERSIÓN BCD
; =========================================
CONVERTIR:
    BANKSEL CONTADOR
    MOVF CONTADOR, W
    MOVWF AUX
    CLRF DECENAS
CONV:
    MOVLW d'10'
    SUBWF AUX, W
    BTFSS STATUS, C
    GOTO FIN_CONV
    MOVWF AUX
    INCF DECENAS, F
    GOTO CONV
FIN_CONV:
    MOVF AUX, W
    MOVWF UNIDADES
    RETURN

; =========================================
; DEMORA PARA MULTIPLEXADO (~5 ms para 4 MHz)
; =========================================
DEMORA_MUX:
    BANKSEL D1
    MOVLW d'5'
    MOVWF D1
MUX1:
    MOVLW d'249'
    MOVWF D2
MUX2:
    NOP
    DECFSZ D2, F
    GOTO MUX2
    DECFSZ D1, F
    GOTO MUX1
    RETURN

    END