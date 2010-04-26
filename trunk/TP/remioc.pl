#!/bin/env perl

use strict;

my $SISTEMA_INICIALIZADO = $ENV{'SISTEMA_INICIALIZADO'};
my $grupo = $ENV{'grupo'};

if(!$SISTEMA_INICIALIZADO){
    print "El sistema no esta inicializado.\n";
    exit 1;
}

#busca todos los remitos que tienen el numero de orden de compra
#especificado
sub buscarRemitos{
    # $1 -> numero de OC
    my $NUMERO = shift(@_);

    opendir(DIR, "$grupo/aceptados/");
    my @RDISPONIBLES = grep(/.*\.$NUMERO\.aproc/,readdir(DIR));
    closedir(DIR);
    
    foreach (@RDISPONIBLES) {
	`Glog "$0" "Remito disponible: $_" I`;
    }

    return @RDISPONIBLES;
}

#Da al usuario la posibilidad de elegir de entre todos los remitos,
#cuáles quiere procesar
sub elegirRemitos(){
    #TODO: MENU
    my @RELEGIDOS=@_;

    foreach (@RELEGIDOS) {
	`Glog "$0" "Remito elegido: $_" I`;
    }
    return @RELEGIDOS
}

#Busca el ultimo archivo de ordenes de compra 
sub buscarUltimaOC(){
    #$_[0] -> ocgob o ocdet
    my $INICIAL=1;
    my $NUMERO;
    opendir(DIR, "$grupo/oc/");
    my @CANDIDATOS = grep(/$_[0]\..*/,readdir(DIR));
    closedir(DIR);

    foreach (@CANDIDATOS){
	
	($NUMERO) = $_ =~ /\.(.*)$/;
	
	if($NUMERO >= $INICIAL){
	    $INICIAL=$NUMERO;
	}
    }

    return $NUMERO;
}

#Procesa la orden de compra con los remitos elegidos.
sub procesarOrden{
    
    my $OCDET = shift(@_);
    my @REMITOS = @_;

    print "Orden: $OCDET\n";
    print "REMITOS: @REMITOS\n";

    

}

#Inicializar el log
`Glog "$0" "Inicio de $0: @ARGV" I`;

my $PARAMETRO = "$ARGV[0]";
#por si tiene espacios en blanco
$PARAMETRO =~ s/^\s+//;
$PARAMETRO =~ s/\s+$//;
my $NUMERO;
my $OC;
my $ULTIMO;

if(length($PARAMETRO) == 6){
    $NUMERO=$PARAMETRO;
    $ULTIMO=&buscarUltimaOC("ocgob");
    $OC="$grupo/oc/ocgob.$ULTIMO";
}

print "Orden de compra: $OC\n";
print "Ultimo $ULTIMO\n";
print "NUMERO: $NUMERO\n";

#Si es orden de compra
if( $OC ){
    #Verifico que este abierta
    `grep "^$NUMERO;[0-9]\\{8\\};[0-9]\\{11\\};ABIERTA;.*" "$OC"`;
    if( $? == 0 ){

	`Glog "$0" "Conciliación de la orden de compra $NUMERO." I`;

	#Busco los remitos que se corresponden
	my @RDISPONIBLES = &buscarRemitos("$NUMERO");
	
	#Dejo al usuario elegir los remitos a procesar
	my @RELEGIDOS = &elegirRemitos(@RDISPONIBLES);

	#Busco el ultimo archivo de descripción de ordenes de compra
	$ULTIMO = &buscarUltimaOC("ocdet");
	my $OCDET = "$grupo/oc/ocdet.$ULTIMO";

	#Procesa cada detalle de orden de compra utilizando los
	#remitos elegidos
	&procesarOrden($OCDET, @RELEGIDOS);
    }
    else{
	#Esta cerrada
	`Glog "$0" "Lo orden de compra $OC, no está abierta." W`;
    }
}
else{
    `Glog "$0" "La orden de compra $OC no existe." E`;
}
