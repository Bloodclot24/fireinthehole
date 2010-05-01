#!/bin/env perl 

use Switch;

sub buscarUltimaOC(){
    #$_[0] -> ocgob o ocdet
    my $INICIAL=1;
    my $NUMERO;
    my @CANDIDATOS = <$grupo/oc/$_[0].*>;

    foreach (@CANDIDATOS){

	($NUMERO) = $_ =~ /\.([0-9]*)$/;
	
	if($NUMERO >= $INICIAL){
	    $INICIAL=$NUMERO;
	}
    }

    return $NUMERO;
}

my $NUMEROARCHIVO = buscarUltimaOC ("ocgob");
my $TOTAL = 0;
my $REMANENTE = 0;

open (ARCHIVO,'<',"$grupo/oc/ocgob.$NUMERO");



#Formato programa -all -salida
#        programa -range mrangominimo rangomaximo -salida
#	 programa -single numero -salida	

#Parseo de parametros
my $ARGC = @ARGV;
my $RANGOMINIMO = 0; 
my $RANGOMAXIMO = 999999;
my $ARCH = 0;
my $STD = 0;
if ($ARGC != 0){
    
  switch ($ARGV[0]) {
    case -f { open (ARCHIVOSALIDA , '>>', "$ARGV[1]"); $ARCH = 1; my $PROXIMOARG = 2 ;}
    case -std { $STD = 1; my $PROXIMOARG = 1;}
    case -b { $STD = 1; $ARCH = 1 ; my $NOMBREARCHIVO = $ARGV[1] ; my $PROXIMOARG = 2;}
    else  {  $STD = 1; my $PROXIMOARG = 0;}
  }

  switch ($ARGV[$PROXIMOARG]){
    case -all { $RANGOMINIMO = 0; $RANGOMAXIMO = 999999;}
    case -range { $RANGOMINIMO = $ARGV[$PROXIMOARG+1]; $RANGOMAXIMO = $ARGV[$PROXIMOARG+2];}
    case -single { $RANGOMINIMO = $ARGV[2]; $RANGOMAXIMO = $ARGV[2];}
    else { $RANGOMINIMO = 0; $RANGOMAXIMO = 999999;}
  }
 
}


while ($LINEA = <ARCHIVO>){
    (my $ESTADO) = $LINEA =~ "^[^;]*;[^;]*;[^;]*;([^;]*);";
    (my $NUMEROOC) = $LINEA =~ "^([^;]*);";
    (my $FECHAOC) = $LINEA =~ "^[^;]*;([^;]*);";
    (my $CUIT) = $LINEA =~ "^[^;]*;[^;]*;([^;]*);";
    (my $FECHAGRABACION) = $LINEA =~ "^[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);";
    if ( $NUMEROOC >= $RANGOMINIMO && $NUMEROOC <= $RANGOMAXIMO ) { 
      if ($ESTADO eq "ABIERTO") {
	#Obtener las sumas totales de las cantidades de la orden de compra detallada.
	$NUMEROARCHIVO = buscarUltimaOC("ocdet");
	open(ARCHIVO2, '<',"$grupo/oc/ocdet.$NUMERO")
	while ($LINEA2 = <ARCHIVO2>){
	  my $NUMEROOCDETALLE = $LINEA2 =~ "^([^;]*);";
	  if ( $NUMEROOC == $NUMEROOCDETALLE ) {
	    $TOTAL+= $LINEA2 =~ "^[^;]*;[^;]*;[^;]*;([^;]*);";
	    $REMANENTE+= $LINEA2 =~ "^[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);";
	  }
	  if ( $TOTAL != 0){
	     my $CUMPLIMIENTO = ($REMANENTE / $TOTAL) * 100;
	  }
	  my $PENDIENTE = $TOTAL - $REMANENTE;
	  
	}
	close ARCHIVO2;
      }
      
      if ( $STD ) {
	  printf ( " Orden de compra numero : %i \n",$NUMEROOC);
	  printf ( " Grado de cumplimiento  : %.2f \n",$CUMPLIMIENTO);
	  printf ( " Fecha de OC            : %s \n",$FECHAOC);
	  if ($ESTADO eq "CERRADO"){
	     printf ( " Fecha de cierre        : %s \n",$FECHAGRABACION);
	  }else { printf (" Pendiente              : %i \n",$PENDIENTE);}
	  printf ( " Proveedor              : %s \n",$CUIT);
	    
      }
	if ( $ARCH ) {
	  printf (ARCHIVOSALIDA, " Orden de compra numero : %i \n",$NUMEROOC);
	  printf (ARCHIVOSALIDA, " Grado de cumplimiento  : %.2f \n",$CUMPLIMIENTO);
	  printf (ARCHIVOSALIDA, " Fecha de OC            : %s \n",$FECHAOC);
	  if ($ESTADO eq "CERRADO"){
	     printf (ARCHIVOSALIDA, " Fecha de cierre        : %s \n",$FECHAGRABACION);
	  }else { printf (ARCHIVOSALIDA, " Pendiente              : %i \n",$PENDIENTE);}
	  printf (ARCHIVOSALIDA, " Proveedor              : %s \n",$CUIT);
	}
	

  }

}
close ARCHIVO;
if ($ARCH) close ARCHIVOSALIDA;