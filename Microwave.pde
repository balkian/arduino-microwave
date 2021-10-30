#include <LiquidCrystal.h>
#include "TimerOne.h"


LiquidCrystal lcd(12, 11, 5, 4, 3, 2);
String keys="123F456E789DA0BC";
int key;
int valores[] = {
903,
876,
819,
747,
710,
693,
656,
585,
536,
527,
506,
483,
473,
465,
448,
200};

enum t_estado {
  PARADO,
  FUNCIONANDO,
  PAUSADO   
};

t_estado estado = PARADO;

enum t_modo {
  MICRO,
  MGRILL,
  GRILL
};
t_modo modo = MICRO;

boolean micro = true;
boolean grill = false;

long contador = 0;
int reloj[] = { 0, 0, 0, 0 };

int potencia = 100;

int pinPuerta = 0;
int pinGrill = 9;
int pinMicro = 10;
int pinResto = 8;

boolean key_lockout=false;

void setup() {
  Serial.begin(9600);
  pinMode(pinPuerta, INPUT);
  attachInterrupt(pinPuerta, puertaAbierta, RISING);
  attachInterrupt(pinPuerta, puertaCerrada, FALLING);

  lcd.begin(16, 2);
  TCCR2B = 0x00;        //Disbale Timer2 while we set it up
  TCNT2  = 130;         //Reset Timer Count to 130 out of 255
  TIFR2  = 0x00;        //Timer2 INT Flag Reg: Clear Timer Overflow Flag
  TIMSK2 = 0x01;        //Timer2 INT Reg: Timer2 Overflow Interrupt Enable
  TCCR2A = 0x00;        //Timer2 Control Reg A: Normal port operation, Wave Gen Mode normal
  TCCR2B = 0x05;        //Timer2 Control Reg B: Timer Prescaler set to 128
  paraPrograma();
}

int count = 0;

ISR(TIMER2_OVF_vect) {
  if ( contador > 0 && estado == FUNCIONANDO ){
      count++;               //Increments the interrupt counter
    if(count > 999){
      contador = contador-1;
      Serial.println("Contador nuevo");
      Serial.println(contador);
      count = 0;           //Resets the interrupt counter
      if( contador == 0 ){
        paraPrograma();
      }
    }
  }
  TCNT2 = 130;           //Reset Timer to 130 out of 255
  TIFR2 = 0x00;          //Timer2 INT Flag Reg: Clear Timer Overflow Flag
}

void loop() {
  // set the cursor to column 0, line 1
  // (note: line 1 is the second row, since counting begins with 0):
  // print the number of seconds since reset:
  key=getKeypad();
  if(key!=-1){
    Serial.print("Pulsado:");
    Serial.println(keys[key]);
    Serial.print("Estado:");
    Serial.println(estado);
    char carac = keys[key];
    if ( estado == PARADO ){
      if( carac >= 48 && carac <= 57 ){
        int digito = carac - 48;
        actualizarReloj(digito);
      }else if( carac == 'A' ) {
        empiezaPrograma();
      }else if( carac == 'F' ){
        cambiaModo();
      }else if( carac == 'E' ){
        cambiaPotencia(10);
      }else if( carac == 'D' ){
        cambiaPotencia(-10);
      }
    }
    else if ( estado == FUNCIONANDO ){
      if( carac == 'C' ) {
        paraPrograma();
      }
      else if( carac == 'A' ) {
        pausaPrograma();
      }
    }
    else if ( estado == PAUSADO ){
      if( carac == 'A' ) {
        empiezaPrograma();
      }
      else if( carac == 'C' ) {
        paraPrograma();
      }else if( carac == 'F' ){
        cambiaModo();
      }else if( carac == 'E' ){
        cambiaPotencia(10);
      }else if( carac == 'D' ){
        cambiaPotencia(-10);
      }
    }
  }
  if( estado == FUNCIONANDO ){
    imprimeRelojArriba();
  }
  delay(100);
}

int getKeypad(){
  int ret=-1;
  boolean reset_lockout=false;
  int leido = analogRead(A0);
  if(leido==0)
    key_lockout=false;
  else if(!key_lockout){
    delay(20);
    for(int i=0; i<16; i++){
       if(valores[i]<leido){
         ret = i;
         break;
       }
    }
      key_lockout=true;
  }
  return ret;
}

void actualizarReloj(int digito){
  for(int i=0; i<3; i++){
   reloj[i] = reloj[i+1];
  }
  reloj[3] = digito;
  imprimeRelojAbajo();
}

void imprimeRelojArriba(){
  contadorAlReloj();
  lcd.setCursor(11, 0);
  char buffer[10];
  sprintf(buffer, "%i%i:%i%i", reloj[0], reloj[1], reloj[2], reloj[3]);
  Serial.print("Contador:");
  Serial.println(contador);
  lcd.print(buffer);
}

void imprimeRelojAbajo(){
  lcd.setCursor(0, 1);
  char buffer[10];
  sprintf(buffer, "%i%i:%i%i", reloj[0], reloj[1], reloj[2], reloj[3]);
  lcd.print(buffer);
}

void imprimeModo(){
  lcd.setCursor(6, 1);
  if( modo == GRILL ){
    lcd.print("GRILL");
  }else if ( modo == MGRILL ){
    lcd.print("M+GR ");
  }else {
    lcd.print("     ");
  }
}

void imprimePotencia(){
  lcd.setCursor(13, 1);
  if( potencia < 100 ){
    lcd.print(potencia);
    lcd.print("%");
  }else {
    lcd.print("   ");
  }
}

void empiezaPrograma(){
  int total = reloj[0]+reloj[1]+reloj[2]+reloj[3];
  if(total > 0 & reloj[2] < 6){
    lcd.setCursor(0, 0);
    lcd.clear();
    lcd.print("Cocinando");
    estado = FUNCIONANDO;
    relojAlContador();
    imprimeRelojArriba();
    imprimeModo();
    imprimePotencia();
  }
}

void pausaPrograma(){
  lcd.setCursor(0, 0);
  lcd.clear();
  lcd.print("Pausa");
  estado = PAUSADO;
  imprimeRelojArriba();
  imprimePotencia();
  imprimeModo();
}

void paraPrograma(){
  lcd.setCursor(0, 0);
  lcd.clear();
  lcd.print("Selecciona tie");
  estado = PARADO;
  borraReloj();
  imprimeRelojAbajo();
  modo = MICRO;
  potencia = 100;
}

void borraReloj(){
  reloj[0] = 0;
  reloj[1] = 0;
  reloj[2] = 0;
  reloj[3] = 0;
  contador = 0;
}

void relojAlContador(){
 contador = (reloj[0]*10+reloj[1])*60+reloj[2]*10+reloj[3];
}

void contadorAlReloj(){
  int segundos = contador % 60;
  int minutos = contador / 60;
  reloj[3] = segundos % 10;
  reloj[2] = segundos / 10;
  reloj[1] = minutos % 10;
  reloj[0] = minutos / 10;
}

void cambiaModo(){
  if( modo == MICRO ){
    modo = GRILL;
  }else if ( modo == GRILL ){
    modo = MGRILL;
  } else if ( modo == MGRILL ){
    modo = MICRO;
  }
  Serial.print("Modo de cocina: ");
  Serial.println(modo);
  imprimeModo();
}

void cambiaPotencia(int incremento){
  potencia = potencia + incremento;
  if( potencia > 100 ){
    potencia = 100;
  }else if ( potencia < 0 ){
    potencia = 0; 
  }
  imprimePotencia();
}

public void puertaAbierta(){
  if( estado == FUNCIONANDO ){
    pausaPrograma();
  }
}

public void puertaCerrada(){
  if( estado == FUNCIONANDO ){
    empiezaPrograma();
  } 
}