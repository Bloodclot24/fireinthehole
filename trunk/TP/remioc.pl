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
	if($CODIGO){
	    $FILAS .= "$CODIGO $_ dummy ";
	    $ARCHIVOS{$CODIGO} = $_;
	}
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
    my (@NUMEROORDEN) = @{$_[0]};
    my (@REMITOS) = @{$_[1]};


    my %ORDENES;
    @ORDENES{@NUMEROORDEN} = ();
    
    
    # extraigo la información de todos los productos de los remitos
    my %PRODUCTOS = ();
    for my $origen (@REMITOS){
    	open(archivo, '<', "$grupo/aceptados/$origen") or die $!;
    	while(<archivo>){
    	    my $CODPROD = $_;
    	    ($CODPROD) = $CODPROD =~ /^[^;]*;([^;]*);/;
    	    my $CANTIDAD = $_;
    	    ($CANTIDAD) = $CANTIDAD =~ /^[^;]*;[^;]*;([^;]*);/;

	    #para el hash, uso la clave: NumeroOrdenDeCompra+CodigoProducto
	    (my $CLAVE) = $origen =~ /^[^.]*\.([^.]*)\..*$/;
	    $CLAVE .= $CODPROD;
    	    $PRODUCTOS{$CLAVE} += $CANTIDAD;
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
	
	(my $CODIGOORDEN) = $linea =~ "^([^;]*);";
	
    	if( exists $ORDENES{$CODIGOORDEN} ){
    	    #la linea es parte de la orden de compra que me interesa (alguna)
    	    (my $CODPROD, my $REMANENTE) = $linea =~ "^[^;]*;[^;]*;([^;]*);([^;]*);";

	    my $CLAVE = $CODIGOORDEN;
	    $CLAVE .= $CODPROD;

    	    my $ESTADO = "ABIERTO";
    	    if($REMANENTE <= $PRODUCTOS{$CLAVE}){
    		$PRODUCTOS{$CLAVE} -= $REMANENTE;
    		$REMANENTE=0;
    		$ESTADO = "CERRADO";
    	    }
    	    else{
    		$REMANENTE -= $PRODUCTOS{$CLAVE};
    		$PRODUCTOS{$CLAVE} = 0;
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
	    (my $CODIGOORDEN) = $clave =~ /^....../;
	    (my $CODIGOPROD) = $clave =~ /..........$/;
    	    print "Error: sobraron $PRODUCTOS{$clave} unidades del producto $CODIGOPROD, en la orden de compra $CODIGOORDEN\n";
    	    `Glog "$0" "Sobraron $PRODUCTOS{$clave} unidades del producto $CODIGOPROD, cuando se intentaba conciliar la orden de compra $CODIGOORDEN" "E"`;
    	}
    }

}

#Inicializar el log
`Glog "$0" "Inicio de $0: @ARGV" I`;

my $PARAMETRO = "$ARGV[0]";
my $NUMERO;
my @OC;
my $OCDET;
my $OCGOB;
my $ULTIMO;
my @REMITOS;

$ULTIMO=&buscarUltimaOC("ocgob");
$NUMERO=$PARAMETRO;

#Por cada parametro, miro si tiene 6 u 8 caracteres. Si tiene 6, me
#guardo el numero como una orden de compra a procesar. Si tiene 8, lo
#tomo como un numero de remito y busco si existe. Si existe, me guardo
#el numero de remito y el numero de orden de compra asociada.

foreach $PARAMETRO (@ARGV){

    if(length($PARAMETRO) == 6){
	push (@OC, $PARAMETRO);
    }
    elsif(length($PARAMETRO) == 8){

	my $archivo = <$grupo/aceptados/$NUMERO.*.aproc>;

	if( -e $archivo ){
	    ($NUMERO) = $archivo =~ /$NUMERO\.([0-9]{6})\.aproc$/;
	    push (@OC, $NUMERO);
	}

	push(@REMITOS , "$grupo/aceptados/$archivo");
    }
    else{
	print "Error: '$PARAMETRO', no identifica una orden de compra o remito.\n";
	exit -1;
    }
}

$OCGOB="$grupo/oc/ocgob.$ULTIMO";

#Si es orden de compra
if( $OCGOB && @OC ){
    #Verifico que esté abierta

    my @aux=@OC;
    @OC = ();
    #verifico que las ordenes de compra elegidas esten abiertas.
    foreach (@aux){
	`grep "^$_;[0-9]\\{8\\};[0-9]\\{11\\};ABIERTA;.*" "$OCGOB"`;
	if( $? == 0 ){
	    push(@OC, $_);
	}
	else{
	    print "Error: La orden de compra $_, no está abierta.\n";
	    `Glog "$0" "La orden de compra $_, no está abierta." E`;
	}
    }

    if(!@OC){
	print "Todas las ordenes de compra especificadas estan cerradas.\n";
	`Glog "$0" "Todas las ordenes de compra especificadas estan cerradas." I`;
	exit -2;
    }

    foreach (@OC){
	#Busco los remitos que se corresponden a cada orden de compra
	my @RDISPONIBLES = &buscarRemitos($_);
	if( ! @RDISPONIBLES){
	    print "No hay remitos disponibles para la orden de compra $NUMERO\n";
	    `Glog "$0" "No hay remitos disponibles para la orden de compra $NUMERO." I`;
	}
	else{
	    push(@REMITOS, @RDISPONIBLES);
	}
    }

    my %auxiliar;
    @auxiliar{@REMITOS} = ();

    @REMITOS = keys %auxiliar;

    if( ! @REMITOS ) {
	print "No hay remitos disponibles para las ordenes de compra solicitadas (@OC).\n";
	`Glog "$0" "No hay remitos disponibles para las ordenes de compra solicitadas (@OC)." I`;
	exit -3;
    }

    `Glog "$0" "Conciliación de la orden de compra @OC." I`;

    #Dejo al usuario elegir los remitos a procesar
    @REMITOS = &elegirRemitos(@REMITOS);


    if( ! @REMITOS){
	print "No se eligió ningun remito.\n";
	exit -4;
    }

    #Busco el ultimo archivo de descripción de ordenes de compra
    $ULTIMO = &buscarUltimaOC("ocdet");
    my $OCDET = "$grupo/oc/ocdet.$ULTIMO";
	
    if( ! $OCDET ){
	print "Error: No se encontro el archivo de descripción de ordenes de compra.";
	`Glog "$0" "No se encontro el archivo de descripción de ordenes de compra." SE`;
	exit -5;
    }

    #Procesa cada detalle de orden de compra utilizando los
    #remitos elegidos
    &procesarOrden($OCDET, \@OC, \@REMITOS);
}
else{
    print "Error: No existe el archivo global de ordenes de compra.\n";
    `Glog "$0" "La orden de compra ??????????? no existe." E`;
}
