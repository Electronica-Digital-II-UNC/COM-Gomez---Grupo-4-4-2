    LIST	P=16F887
    #include <p16f887.inc>
	
CONTADOR    EQU	    0x20
UNIDADES    EQU	    0x21
DECENAS	    EQU	    0x22
MUX	    EQU	    0x23
BOTON	    EQU	    0x24
AUX	    EQU	    0x25
	    
    ORG	0x0000
    GOTO	INICIO
	
    ORG	0x04
INICIO:
    BANKSEL	ANSEL
    CLRF	ANSEL
    CLRF	ANSELH
	
    BANKSEL PORTA
    CLRF	PORTA
	
    BANKSEL	PORTC
    CLRF	PORTC	
	
    BANKSEL PORTD
    CLRF	PORTD
	
    BANKSEL TRISC
    BCF	TRISC,0
    BCF	TRISC,1
    BCF	TRISC,2
    BCF	TRISC,3
    BCF	TRISC,4
    BCF	TRISC,5
	
    BANKSEL TRISA
    BCF	TRISA,0
    BCF	TRISA,1
    BCF	TRISA,2
    BCF	TRISA,3
	
    BANKSEL	TRISD
    CLRF	TRISD
	
    BANKSEL TRISB
    BSF	TRISB,1
    BSF	TRISB,5
    
    BANKSEL OPTION_REG
    BCF     OPTION_REG,7   
    
    BANKSEL WPUB
    BSF     WPUB,1         
    
    BANKSEL CONTADOR
    CLRF    CONTADOR
    CLRF    MUX
    CLRF    BOTON
    CALL    CONV
	
MAIN:
    CALL	MULTIPLEXAR
    CALL	CHEQUEO_BOTON
    GOTO	MAIN
	
MULTIPLEXAR:
    BANKSEL PORTA
    BCF	    PORTA,2
    BCF	    PORTA,3
    
    BANKSEL MUX
    BTFSS   MUX,0
    GOTO    M_UNIDADES
    
M_DECENAS:
    BANKSEL DECENAS
    MOVF    DECENAS,W
    CALL    TABLA
    CALL    DISPLAY
    
    BANKSEL PORTA
    BSF	    PORTA,3
    GOTO    FIN_MUX
    
M_UNIDADES:
    BANKSEL UNIDADES
    MOVF    UNIDADES,W
    CALL    TABLA
    CALL    DISPLAY
    
    BANKSEL PORTA
    BSF	    PORTA,2
    GOTO    FIN_MUX
    
FIN_MUX:
    BANKSEL MUX
    COMF    MUX,F
    
;    CALL    RETARDO_5MS
    RETURN
    
DISPLAY:
    BANKSEL PORTC
    MOVWF   PORTC     
    
    BANKSEL AUX
    MOVWF   AUX         
    
    BTFSS   AUX,6     
    GOTO    APAGAR_G   
    
ENCENDER_G:
    BANKSEL PORTA
    BSF     PORTA,0  
    RETURN
    
APAGAR_G:
    BANKSEL PORTA
    BCF     PORTA,0 
    RETURN
    
CHEQUEO_BOTON:
    BANKSEL BOTON
    BTFSC   BOTON,0
    GOTO    ESPERAR_LIBERACION
    
ESPERAR_PRESION:
    BANKSEL PORTB
    BTFSC   PORTB,1       
    RETURN                 
    
    BANKSEL BOTON
    BSF     BOTON,0  
    
    BANKSEL CONTADOR
    INCF    CONTADOR,F
    
    ; Límite 0 a 99
    MOVLW   d'100'
    SUBWF   CONTADOR,W
    BTFSC   STATUS,Z
    CLRF    CONTADOR
    
    ; Prender leds
    MOVF    CONTADOR,W
    BANKSEL PORTD
    MOVWF   PORTD           
    
    CALL    CONV   
    RETURN

ESPERAR_LIBERACION:
    BANKSEL PORTB
    BTFSS   PORTB,1      
    RETURN            
    
    BANKSEL BOTON
    BCF     BOTON,0    
    RETURN


CONV:
    BANKSEL CONTADOR
    MOVF    CONTADOR,W
    MOVWF   AUX             ; Copiamos contador a AUX
    CLRF    DECENAS         ; Empezamos decenas en 0
    
RESTA_10:
    MOVLW   d'10'
    SUBWF   AUX,W           ; Restamos 10 a AUX
    BTFSS   STATUS,C        ; Chequeamos si el carry es 0
    GOTO    FIN_RESTA       
    MOVWF   AUX            
    INCF    DECENAS,F       
    GOTO    RESTA_10
    
FIN_RESTA:
    MOVF    AUX,W
    MOVWF   UNIDADES      
    RETURN
    
    
TABLA:
    ADDWF   PCL,F
    RETLW   b'00111111'
    RETLW   b'00000110'
    RETLW   b'01011011'
    RETLW   b'01001111'
    RETLW   b'01100110'
    RETLW   b'01101101'
    RETLW   b'01111101'
    RETLW   b'00000111'
    RETLW   b'01111111'
    RETLW   b'01100111'
    
    END


