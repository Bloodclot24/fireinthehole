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
    my @RDISPONIBLES = grep(/.*\.$NUMERO\.aproc$/,readdir(DIR));
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

    return () if ($#_+1 == 0);

    my $FILAS;
    my %ARCHIVOS;
    foreach (@_){
	(my $CODIGO) = $_ =~ /(.*)\..+\.aproc$/;
	$FILAS .= "$CODIGO $_ dummy ";
	$ARCHIVOS{$CODIGO} = $_;
    }

    my $ELEGIDOS=`dialog  --checklist \"Lista de remitos\"  24 50 12 $FILAS --stdout 2>/dev/null`;

    return () if $? != 0;

    (my @TEMPORAL) = $ELEGIDOS =~ /"([^"]*)"/g;
    my @RELEGIDOS;

    foreach (@TEMPORAL){
	push(@RELEGIDOS, $ARCHIVOS{$_});
    }

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
    my @CANDIDATOS = <$grupo/oc/$_[0].*>;

    foreach (@CANDIDATOS){

	($NUMERO) = $_ =~ /\.([0-9]*)$/;
	
	if($NUMERO >= $INICIAL){
	    $INICIAL=$NUMERO;
	}
    }

    return $NUMERO;
}

#Procesa la orden de compra con los remitos elegidos.
sub procesarOrden{
    
    my $OCDET = shift(@_);
    my $NUMEROORDEN = shift(@_);
    my @REMITOS = @_;

    # extraigo la información de todos los productos de los remitos
    my %PRODUCTOS = ();
    for my $origen (@REMITOS){
	open(archivo, '<', "$grupo/aceptados/$origen") or die $!;
	while(<archivo>){
	    my $CODPROD = $_;
	    ($CODPROD) = $CODPROD =~ /^[^;]*;([^;]*);/;
	    my $CANTIDAD = $_;
	    ($CANTIDAD) = $CANTIDAD =~ /^[^;]*;[^;]*;([^;]*);/;

	    $PRODUCTOS{$CODPROD} += $CANTIDAD;
	}
	
	close archivo;
	(my $destino) = $origen =~ /^(.*)\.aproc$/;
	$destino .= ".proc";
	`Glog $0 "Renombrando aceptados/$origen a aceptados/$destino" I`;
	if (! rename "$grupo/aceptados/$origen", "$grupo/aceptados/$destino"){
	    `Glog $0 "No se puede renombrar aceptados/$origen a aceptados/$destino" SE`;
	    return -1;
	}
    }

    #ahora, genero un nuevo OCDET y voy procesando los productos
    #TODO: cerrar ordenes en OCGOB

    (my $OCDET2) = $OCDET =~ /^(.*)\..*$/;
    (my $NUMERO) = $OCDET =~ /^.*\.(.*)$/;
    $NUMERO++;
    $OCDET2 .= ".$NUMERO";
    open archivo, '<', $OCDET or die $!;
    open archivo2, '>', $OCDET2 or die $!;

    while(my $linea = <archivo>){
	if( $linea =~ "^$NUMEROORDEN;"){
	    #la linea es parte de la orden de compra que me interesa
	    (my $CODPROD, my $REMANENTE) = $linea =~ "^[^;]*;[^;]*;([^;]*);([^;]*);";

	    my $ESTADO = "ABIERTO";
	    if($REMANENTE <= $PRODUCTOS{$CODPROD}){
		$PRODUCTOS{$CODPROD} -= $REMANENTE;
		$REMANENTE=0;
		$ESTADO = "CERRADO";
	    }
	    else{
		$REMANENTE -= $PRODUCTOS{$CODPROD};
		$PRODUCTOS{$CODPROD} = 0;
	    }

	    $linea =~ s/^([^;]*;[^;]*;[^;]*);[^;]*;([^;]*);[^;]*;(.*)$/$1;$REMANENTE;$2;$ESTADO;$3/;

	    print archivo2 $linea;
	}
	else{
	    #la linea no me interesa, la guardo sin modificarla
	    print archivo2 $linea;
	}
    }

    close archivo;
    close archivo2;

    for my $clave (keys %PRODUCTOS){
	if($PRODUCTOS{$clave} > 0){
	    print "Error: sobraron $PRODUCTOS{$clave} unidades del producto $clave\n";
	    `Glog "$0" "Sobraron $PRODUCTOS{$clave} unidades del producto $clave, cuando se quería conciliar la orden de compra $NUMEROORDEN." "E"`;
	}
    }

}

#Inicializar el log
`Glog "$0" "Inicio de $0: @ARGV" I`;

my $PARAMETRO = "$ARGV[0]";
my $NUMERO;
my $OC;
my $ULTIMO;
my $REMITO;

$ULTIMO=&buscarUltimaOC("ocgob");
$NUMERO=$PARAMETRO;

if(length($PARAMETRO) == 6){
    $OC="$grupo/oc/ocgob.$ULTIMO";
}
elsif(length($PARAMETRO) == 8){

    my $archivo = <$grupo/aceptados/$NUMERO.*.aproc>;

    if( -e $archivo ){
	($NUMERO) = $archivo =~ /$NUMERO\.([0-9]{6})\.aproc$/;
    }
	
    chomp $REMITO;
}
$OC="$grupo/oc/ocgob.$ULTIMO";

#Si es orden de compra
if( $OC ){
    #Verifico que este abierta
    `grep "^$NUMERO;[0-9]\\{8\\};[0-9]\\{11\\};ABIERTA;.*" "$OC"`;
    if( $? == 0 ){

	`Glog "$0" "Conciliación de la orden de compra $NUMERO." I`;

	#Busco los remitos que se corresponden
	my @RDISPONIBLES = &buscarRemitos("$NUMERO");
	if( ! @RDISPONIBLES){
	    print "No hay remitos disponibles para la orden de compra $NUMERO\n";
	    `Glog "$0" "No hay remitos disponibles para la orden de compra $NUMERO." I`;
	    exit 1;
	}
	
	#Dejo al usuario elegir los remitos a procesar
	my @RELEGIDOS = &elegirRemitos(@RDISPONIBLES);
	
	if( ! @RELEGIDOS){
	    exit 2;
	}

	#Busco el ultimo archivo de descripción de ordenes de compra
	$ULTIMO = &buscarUltimaOC("ocdet");
	my $OCDET = "$grupo/oc/ocdet.$ULTIMO";
	
	if( ! $OCDET ){
	    print "Error: No se encontro el archivo de descripción de ordenes de compra.";
	    `Glog "$0" "No se encontro el archivo de descripción de ordenes de compra." SE`;
	    exit 3;
	}

	#Procesa cada detalle de orden de compra utilizando los
	#remitos elegidos
	&procesarOrden($OCDET, $NUMERO, @RELEGIDOS);
    }
    else{
	#Esta cerrada
	print "Error: La orden de compra $OC, no está abierta.";
	`Glog "$0" "La orden de compra $OC, no está abierta." E`;
    }
}
elsif($REMITO){

}
else{
    `Glog "$0" "La orden de compra $OC no existe." E`;
}
