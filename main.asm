;TOMAS PUTO
; TP -Calidad del Aire-.asm
;AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
; Created: 4/10/2024 14:22:00
; Author : carru
	.ORG	0X0000
	JMP	INICIO
	.ORG	0X0016
	JMP INT_CTC
	.ORG	0X002A
	JMP INT_ADC
INICIO:
	LDI R23, 0
	LDI R24, 0
;confijuracion de pila
	LDI	R16,HIGH(RAMEND)
	OUT	SPH,R16
	LDI	R16,LOW(RAMEND)
	OUT	SPL,R16
	CALL INT_
; fin configuracion de pila
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
; configuracion de conversion ADC
    LDI	R16,(1<<ADLAR)|(1<<REFS0)//CONFIGURAMOS EL ADC con resolucion de 8 bits;configurado para que la tension de referencia sea VCC
	STS ADMUX,R16//	cargamos las habilitaciones al registro ADMUX
	LDI R16,(1<<ADEN)|(1<<ADATE)|(1<<ADIE)|(1<<ADPS2)|(1<<ADPS1)// activamos el conversor, habilitamos el auto trigger, habilitamos la interrrupcion del adc y dividimos la frecuencia x64
	STS ADCSRA, R16// las habilitaciones anteriores las cargamos en el registro
	LDI R16, (1<<ADTS1)|(1<<ADTS0)// elegimos la fuente de auto trigger (COMPARACION del canal A del timer 1)
	STS ADCSRB, R16//las habilitaciones anteriores las cargamos en el registro
	LDI R16,(1<<ADC0D)|(1<<ADC1D)|(1<<ADC2D)|(1<<ADC3D)|(1<<ADC4D)//desactivamos el buffer digital de los pines para dejarlos solo analogicos 
	STS DIDR0, R16//las habilitaciones anteriores las cargamos en el registro
; fin configuracion ADC
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
;configuracion del TIMER 1 modo CTC (interrupcion)
INT_:
	LDI	R16,0
	STS	TCCR1A,R16 ;dejamos este registro en cero ya que queremos usar el timer en modo CTC para formar una temporizacion
	LDI	R16,(1<<WGM12)|(1<<CS12)//seleccionamos el modo CTC con wgm12 / determinamos los bits para elegir el valor del prescaler que queremos (clk/256) para la fuente de reloj
	STS	TCCR1B,R16// cargamos los bit en el registro de control B
	LDI	R16,0
	STS	TCCR1C,R16 // sirve para forzar una comparación de salida, pero no se modifica nada ya que no es necesario en nuestro caso
	LDI	R16,(1<<OCIE1A)// habilitamos la interrupcion por comparacion de A
	STS	TIMSK1,R16// cargamos el bit de habilitacion de la interrupcion por comparacion de A
	LDI	R16,HIGH(12499)// como el valor es superior a 255 ya que el registro es de 8 bit se carga en dos partes parte alta
	STS	OCR1AH,R16//cargamos la parte alta  del valor e comparación para el temporizador en modo CTC, determinando cuándo debe generarse una interrupción o un evento de salida cuando el temporizador alcanza ese valor.
	LDI	R16,LOW(12499)// cargamos la parte baja del valor
	STS	OCR1AL,R16// la ingresamos en el registro de comparacion
	SEI
;fin de configuracion del TIMER 1
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	INT_CTC:
	
	RETI
;interrupcion generada cuando se termina de convertir en un canal del ADC
INT_ADC:
    PUSH    R16
    IN      R16,SREG
    PUSH    R16
	PUSH	R18
	///////////
	CP R23, R24 // los registros estan en cero
	BREQ VERDADERO // compara si los registros son iguales. si no son iguales salta a SIG_ADCx
RJMP SIG_ADC
	VERDADERO:
	LDS R18, ADCH // CARGO VALOR DEL ADC0
	STS 0X0100, R18// guardo en la RAM el valor del ADC0 (CONCENTRACION DE CO2)
	INC R23 // regitro = 1
	LDI R16, (1<<ADLAR)|(1<<REFS0)|(1<<MUX0)// configuramos para cambiar al siguiente canal post conversion|ADC1(0001)
	STS ADMUX, R16
	JMP RETURN
SIG_ADC:
	INC R24 //
	CP R23, R24
	BREQ VERDADERO1
RJMP SIG_ADC1
	VERDADERO1:
	LDS R18, ADCH // CARGO VALOR DEL ADC1
	STS 0X0101, R19// guardo en la RAM el valor del ADC1(GASES INFLAMABLES) 
	LDI R23, 3
	LDI R16, (1<<ADLAR)|(1<<REFS0)|(1<<MUX1)// ADC2(0010)
	STS ADMUX, R16
	JMP RETURN
SIG_ADC1:
	INC R24
	CP R23, R24
	BREQ VERDADERO2
RJMP SIG_ADC2
	VERDADERO2:
	LDS R18, ADCH // CARGO VALOR DEL ADC2
	STS 0X0102, R20// guardo en la RAM el valor del ADC2(PARTICULAS EN SUSPENSION) 
	LDI R23, 6
	LDI R16, (1<<ADLAR)|(1<<MUX1)|(1<<MUX0)// ADC3(0011) OJO TENSION DE REFERNECIA 2.55V
	STS ADMUX, R16
	JMP RETURN
SIG_ADC2:
	INC R24
	CP R23, R24
	BREQ VERDADERO3
RJMP SIG_ADC3
	VERDADERO3:
	LDS R18, ADCH // CARGO VALOR DEL ADC3
	STS 0X0103, R21// guardo en la RAM el valor del ADC3(TEMPERATURA AMBIENTE) MODIFICAR TENSION DE REF
	LDI R23, 10  
	LDI R16, (1<<ADLAR)|(1<<REFS0)|(1<<MUX2)// ADC4(0100)
	STS ADMUX, R16
	JMP RETURN
SIG_ADC3:
	LDS R18, ADCH // CARGO VALOR DEL ADC4
	STS 0X0104, R22// guardo en la RAM el valor del ADC4(HUMEDAD RELATIVA)
	LDI R16, (1<<ADLAR)|(1<<REFS0)// DEJO NUEVAMENTE ADC0
	STS ADMUX, R16
	LDI R23, 0//CUANDO TERMINE LOS 5 CANALES DEL ADC RETORNAR LOS REGISTROS R23 A 0
	LDI R24, 0//CUANDO TERMINE LOS 5 CANALES DEL ADC RETORNAR LOS REGISTROS R24 A 0
	JMP RETURN
	RETURN:
	////////
	POP     R16
    OUT     SREG,R16
    POP     R16
	POP	R18
	RETI
; FIN interrupcion generada cuando se termina de convertir en un canal del ADC
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
;Manipulacion de los datos obtenidos 
; CONVERSION CONCENTRACION DE C02
	LDS R16, 0X0100
	LDI R17, 20// constante, cuando el ADC lea 0 las ppm seran 20
	LDI R18, 10// por cada unidad de aumneto del adc equivale a 10ppm
	ADD R16, R17// sumamos la constante al valor dado por el ADC
	MUL R16, R18// multiplicamos por el valor de cada unidad
	STS 0X0121, R0//PARTE BAJA DE LA MULTIPLICACION
	STS 0X0122, R1// PARTE ALTA DE LA MULTIPLICACION
;CONVERSION DE GASES INFLAMABLES 

;CONVERSION DE PARTICULAS EN SUSPENCION 0.5V/(100ug/m3)
	LDS R16, 0X0102
	LDI R17, 4// cada bit lo multiplicamos por 4 para hacer que cada valor corresponda a 4 microgramos/m3
	MUL R16, R17
	STS 0X0123, R0
	STS 0X0124, R1
; CONVERSION DE BITS A TEMPERATURA
	LDS R16, 0X0103// extraemos de la memoria el valor de la conversion ADC 
	LDI R17, 50// colocamos la constante para hacer que el valor en decima uno sea igual a 1°C
	CP R16, R17// comparamos para ver si la bandera nos determina que el resultado sera negativo o no
	BRLT VERDADERO4// ahora si es positivo realizamos de una forma la resta y si es negativo la restamos inversamente 
	SUB R16, R17
	STS 0X0123, R16
	JMP FINBR
VERDADERO4:
	SUB R17, R16
	STS 0X0123, R17// aqui si es negativo el numero se guarda como positivo pero despues se representa como negativo
FINBR:
;CONVERSION DE BITS A PORCENTAJE DE HUMEDAD RELATIVA
	LDS R16, 0X0104
	LDI R17, 30
	SUB R16, R17
	STS 0X0124, R16

