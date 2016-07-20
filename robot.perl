#!/usr/local/bin/perl
#
# Lectura de links y enlaces
# Input : Archivo con URLs
#
use strict;
use warnings;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request::Common qw(GET);
use XML::Simple;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use WWW::Mechanize;
use HTML::HeadParser;
use POSIX qw(strftime);
use Encode qw(decode encode);
#use Net::SMTP::SSL;
use MIME::Base64;
use File::Spec;
use LWP::MediaTypes;
use Net::FTP;
# instalar Mozilla::CA

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

sub debug{
	
	# Configuración para imprimir debug en pantalla
	my $debug = 1;
	
	if ($debug == 1) {

		if ($_[0] eq 'blank') {
			
			print "\n";
			
		}
		else {

			my $time = strftime "%Y.%m.%d / %H.%M.%S", localtime;
			print "debug $time :: $_[0] $_[1]\n";
			
		}
	}	
}

sub send_mail_with_attachments {
 my $to = shift(@_);
 my $subject = shift(@_);
 my $body = shift(@_);
 my @attachments = @_;

 my $from = '';
 my $password = '';
 my $smtp;

 if (not $smtp = Net::SMTP::SSL->new('smtp.gmail.com',
                              Port => 465,
                              Debug => 1)) {
     die "Could not connect to server\n";
 }

 # Authenticate
 $smtp->auth($from, $password)
     || die "Authentication failed!\n";

 # Create arbitrary boundary text used to seperate
 # different parts of the message
 my ($bi, $bn, @bchrs);
 my $boundry = "";
 foreach $bn (48..57,65..90,97..122) {
     $bchrs[$bi++] = chr($bn);
 }
 foreach $bn (0..20) {
     $boundry .= $bchrs[rand($bi)];
 }

 # Send the header
 $smtp->mail($from . "\n");
 my @recepients = split(/,/, $to);
 foreach my $recp (@recepients) {
     $smtp->to($recp . "\n");
 }

 $smtp->data();
 $smtp->datasend("From: " . $from . "\n");
 $smtp->datasend("To: " . $to . "\n");
 $smtp->datasend("Subject: " . $subject . "\n");
 $smtp->datasend("MIME-Version: 1.0\n");
 $smtp->datasend("Content-Type: multipart/mixed; BOUNDARY=\"$boundry\"\n");

 # Send the body
 $smtp->datasend("\n--$boundry\n");
 $smtp->datasend("Content-Type: text/plain\n");
 $smtp->datasend($body . "\n\n");

 # Send attachments
 foreach my $file (@attachments) {
     unless (-f $file) {
         die "Unable to find attachment file $file\n";
         next;
     }
     my($bytesread, $buffer, $data, $total);
     open(FH, "$file") || die "Failed to open $file\n";
     binmode(FH);
     while (($bytesread = sysread(FH, $buffer, 1024)) == 1024) {
         $total += $bytesread;
         $data .= $buffer;
     }
     if ($bytesread) {
         $data .= $buffer;
         $total += $bytesread;
     }
     close FH;

     # Get the file name without its directory
     my ($volume, $dir, $fileName) = File::Spec->splitpath($file);
  
     # Try and guess the MIME type from the file extension so
     # that the email client doesn't have to
     my $contentType = guess_media_type($file);
	 
	 $contentType = "text/plain; charset=UTF-8";
  
     if ($data) {
         $smtp->datasend("--$boundry\n");
         $smtp->datasend("Content-Type: $contentType; name=\"$fileName\"\n");
         $smtp->datasend("Content-Transfer-Encoding: base64\n");
         $smtp->datasend("Content-Disposition: attachment; =filename=\"$fileName\"\n\n");
         $smtp->datasend(encode_base64($data));
         $smtp->datasend("--$boundry\n");
     }
 }

 # Quit
 $smtp->datasend("\n--$boundry--\n"); # send boundary end message
 $smtp->datasend("\n");
 $smtp->dataend();
 $smtp->quit;
}

# Algunas variables de inicio
my $horainicio = strftime "%Y.%m.%d / %H.%M.%S", localtime;
my $date = strftime "%Y.%m.%d", localtime;

my $path = "/home/desarrollo/Escritorio/Comparador de Precios/comparador";
my $file = "$path/$ARGV[0]";
my $filelog = "$path/comparador-$date.csv";
my $filecmp = "$path/tmp.csv";

open (FH, "< $file") or die "Can't open $file for read: $!";
my @lines = <FH>;
close FH or die "Cannot close $file: $!"; 

my $prodva;
my $marcava;
my $priceva;
my $statusva;

my $prodv2;
my $marcav2;
my $pricev2;
my $priceant;
my $statusv2;
my $dif;

open (LOG,"> $filelog") || die "No se pudo crear el archivo\n";

print LOG "Fecha;URL 1;Proveedor 1;Descripcion 1;Marca 1;Precio 1;URL 2;Proveedor 2;Descripcion 2;Marca 2;Precio 2;Precio Anterior;Disponibilidad 2;Dif\n";

my $i = 1;
my $haycambios = 0;

foreach my $lines (@lines) {
	
	$prodva = "";
	$marcava = "";
	$priceva = "";
	$statusva = "";
	
	$prodv2 = "";
	$marcav2 = "";
	$pricev2 = "";
	$priceant = "";
	$statusv2 = "";
	$dif = "";
	
	my @URL =  split(/;/, $lines);
	
	debug("Numero           ", $i);
	debug("URL Comercio    ", $URL[0]);
	debug("URL Competencia  ", $URL[1]);
	
	my @dominio = split(/\./, $URL[1]);
	
	debug("Competidor       ", $dominio[1]);
	debug("blank");
	
	# Obtiene Código HTML de la URL
    my $ua = LWP::UserAgent->new;
	$ua->timeout(20);
	$ua->env_proxy;

    # Define user agent type
    $ua->agent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.153 Safari/537.36');

    # Request object
    my $response = $ua->get($URL[0]);
	my $htmltxt = $response->content;
	
	#print "\n\n$htmltxt\n\n";
	
	while ($htmltxt =~ /itemprop.\"name\".{0,50}/gisx) { 
		
		#print "$&\n";
		my @n1 = split (/\</, $&);
		my @n2 = split (/\>/, $n1[0]);
		
		$prodva = $n2[1];
		$prodva =~ s/^\s*(.*?)\s*$/$1/;
				
	}
	
	while ($htmltxt =~ /itemprop.\"brand\".{0,50}/gisx) { 
		
		#print "$&\n";
		my @n1 = split (/\</, $&);
		my @n2 = split (/\>/, $n1[0]);
		
		$marcava = $n2[1];
		$marcava =~ s/^\s*(.*?)\s*$/$1/;
			
	}
	
	while ($htmltxt =~ /itemprop.\"price\".{0,200}/gisx) { 
				
		#print "PRECIO\n$&\n\n";
		my @n1 = split (/\</, $&);
		my @n2 = split (/\>/, $n1[1]);
		
		$priceva = $n2[1];
		$priceva =~ s/\$//g;
		$priceva =~ s/\.//g;
		$priceva =~ s/^\s*(.*?)\s*$/$1/;
		$priceva =~ s/\D//g;
			
	}
	
	if ( $priceva eq "") {
				
		while ($htmltxt =~ /product-price-.{0,200}/gisx) { 
				
			#print "$&\n";
			
			my @n1 = split (/\</, $&);
			my @n2 = split (/\>/, $n1[0]);
		
			$priceva = $n2[1];
			$priceva =~ s/\$//g;
			$priceva =~ s/\.//g;
			$priceva =~ s/^\s*(.*?)\s*$/$1/;
			$priceva =~ s/\D//g;
			
		}
				
		
	}
	
    $ua = LWP::UserAgent->new;
	$ua->timeout(20);
	$ua->env_proxy;

    # Define user agent type
    $ua->agent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.153 Safari/537.36');

    # Request object
    $response = $ua->get($URL[1]);
	$ua->ssl_opts( verify_hostname => 0 );
	$htmltxt = $response->content;
	
	#print "-------\n\n$htmltxt\n--------\n";
	
	if ( $dominio[1] eq 'dafiti' ) {
		
		while ($htmltxt =~ /itemprop.\"name\".{0,50}/gisx) { 
		
			#print "$&\n";
			my @n1 = split (/\</, $&);
			my @n2 = split (/\>/, $n1[0]);
		
			$prodv2 = $n2[1];
			$prodv2 =~ s/^\s*(.*?)\s*$/$1/;
				
		}
	
		while ($htmltxt =~ /itemprop.\"brand\".{0,50}/gisx) { 
		
			#print "$&\n";
			my @n1 = split (/\</, $&);
			my @n2 = split (/\>/, $n1[0]);
		
			$marcav2 = $n2[1];
			$marcav2 =~ s/^\s*(.*?)\s*$/$1/;
			
		}
	
		while ($htmltxt =~ /meta.content.{0,15}itemprop.\"price\"/gisx) { 
		
			#print "$&\n";
			my @n1 = split (/\"/, $&);
			my @n2 = split (/\"/, $n1[1]);
		
			$pricev2 = $n2[0];
			$pricev2 =~ s/^\s*(.*?)\s*$/$1/;
			
			my @n3 = split (/\./, $pricev2);
			$pricev2 = $n3[0];
			$pricev2 =~ s/\D//g;
				
		}
		
		while ($htmltxt =~ /data-stockstore.{0,200}/gisx) { 
		
			#print "STATUS $&\n";
			my @n1 = split (/:/, $&);
			my @n2 = split (/\}/, $n1[1]);
		
			$statusv2 = $n2[0];
			$statusv2 =~ s/^\s*(.*?)\s*$/$1/;
			
			#print "AERS $statusv2\n\n";
			
			if ($statusv2 eq '0') {
				
				$statusv2 = "NO DISPONIBLE";
				
			}
			
			else { $statusv2 = "DISPONIBLE"; }
				
		}
		
		
		
	}
	
	elsif ( $dominio[1] eq 'allnutrition') {
						
		while ($htmltxt =~ /itemprop.\"name\".{0,50}/gisx) { 
		
			#print "\n\n$&\n\n";
			my @n1 = split (/\</, $&);
			my @n2 = split (/\>/, $n1[0]);
		
			$prodv2 = $n2[1];
			$prodv2 =~ s/^\s*(.*?)\s*$/$1/;
				
		}
	
		while ($htmltxt =~ /itemprop.\"brand\".{0,50}/gisx) { 
		
			#print "\n\n$&\n\n";
			my @n1 = split (/\</, $&);
			my @n2 = split (/\>/, $n1[0]);
		
			$marcav2 = $n2[1];
			$marcav2 =~ s/^\s*(.*?)\s*$/$1/;
			
		}
	
		while ($htmltxt =~ /product-price-.{2,4}_clone.{0,50}/gisx) { 
		
			#print "\n\n$&\n\n";
			my @n1 = split (/\"/, $&);
			my @n2 = split (/\"/, $n1[1]);
		
			$pricev2 = $n2[0];
			$pricev2 =~ s/^\s*(.*?)\s*$/$1/;
			
			#my @n3 = split (/\./, $pricev2);
			#$pricev2 = $n3[0];
			$pricev2 =~ s/\D//g;
				
		}
		
		if ($pricev2 eq "") {
			
			while ($htmltxt =~ /product-price-.{2,4}\".{0,50}/gisx) { 
		
				#print "\n\n$&\n\n";
				my @n1 = split (/\"/, $&);
				my @n2 = split (/\"/, $n1[1]);
		
				$pricev2 = $n2[0];
				$pricev2 =~ s/^\s*(.*?)\s*$/$1/;
			
				#my @n3 = split (/\./, $pricev2);
				#$pricev2 = $n3[0];
				$pricev2 =~ s/\D//g;
			
			}
			
		}
		
		if ($pricev2 eq "") {
			
			while ($htmltxt =~ /\<span.class\=\"regular-price\".id\=\"product-price-.{2,4}\"\>.{0,100}/gisx) { 
		
				#print "\nULTIMO\n$&\n\n";
				my @n1 = split (/\</, $&);
				
				#print "0 $n1[0]\n";
				#print "1 $n1[1]\n";		
				#print "2 $n1[2]\n";						
				
				my @n2 = split (/\>/, $n1[2]);
		
				$pricev2 = $n2[1];
				$pricev2 =~ s/^\s*(.*?)\s*$/$1/;
			
				#my @n3 = split (/\./, $pricev2);
				#$pricev2 = $n3[0];
				$pricev2 =~ s/\D//g;
			
			}
			
		}
		
		$statusv2 = "NO DISPONIBLE";
		
		while ($htmltxt =~ /productAddToCartForm.submit\(this\).{0,1}/gisx) { 
		
			#print "\n\n$&\n\n";
		
			$statusv2 = "DISPONIBLE";
	
		}
		
		
	}

	#ACA AGREGO NUEVOS DOMINIOS
		elsif ( $dominio[1] eq 'linio' ) {		
			while ($htmltxt =~ /itemprop.\"name\".{0,50}/gisx) { 		
				#print "$&\n";
				my @n1 = split (/\</, $&);
				my @n2 = split (/\>/, $n1[0]);
		
				$prodv2 = $n2[1];
				$prodv2 =~ s/^\s*(.*?)\s*$/$1/;				
			}
			while ($htmltxt =~ /itemprop.\"brand\".{0,50}/gisx) { 
		
				#print "$&\n";
				my @n1 = split (/\</, $&);
				my @n2 = split (/\>/, $n1[0]);
		
				$marcav2 = $n2[1];
				$marcav2 =~ s/^\s*(.*?)\s*$/$1/;
			
			}
			while ($htmltxt =~ /meta.content.{0,15}itemprop.\"price\"/gisx) { 		
				#print "$&\n";
				my @n1 = split (/\"/, $&);
				my @n2 = split (/\"/, $n1[1]);
		
				$pricev2 = $n2[0];
				$pricev2 =~ s/^\s*(.*?)\s*$/$1/;
			
				my @n3 = split (/\./, $pricev2);
				$pricev2 = $n3[0];
				$pricev2 =~ s/\D//g;
				
			}
			if ($pricev2 eq "") {
				#while ($htmltxt =~ /property.\"gr:HasCurrencyValue\".{0,100}/gisx) { 		
				while ($htmltxt =~ /itemprop.\"price\".{0,100}/gisx) { 		
					#print "$&\n";
					my @n1 = split (/\</, $&);
					my @n2 = split (/\>/, $n1[0]);
					@n2 = split (/\="price" /, $&);
					@n2 = split (/\ /, $&);
					@n2 = split (/\"/, $&);
					my @n4 = split (/\./, $n2[3]);				
					$pricev2 = $n4[0];
					$pricev2 =~ s/^\s*(.*?)\s*$/$1/;
				}
			}
			if ($pricev2 eq "") {
				while ($htmltxt =~ /\<span.property\=\"gr:hasCurrency\".{0,30}\"\>.{0,100}/gisx) { 
					#print "\nULTIMO\n$&\n\n";
					my @n1 = split (/\</, $&);
					#print "0 $n1[0]\n";
					#print "1 $n1[1]\n";		
					#print "2 $n1[2]\n";						
					my @n2 = split (/\>/, $n1[2]);
					$pricev2 = $n2[1];
					$pricev2 =~ s/^\s*(.*?)\s*$/$1/;
					#my @n3 = split (/\./, $pricev2);
					#$pricev2 = $n3[0];
					$pricev2 =~ s/\D//g;
				}			
			}
			$statusv2 = "NO DISPONIBLE";
		
			while ($htmltxt =~ /AddToCart/gisx) { 
		
				$statusv2 = "DISPONIBLE";
	
			}
		
			#/\<span.class\=\"regular-price\".id\=\"product-price-.{2,4}\"\>.{0,100}/gisx
			while ($htmltxt =~ /\div.id\=\"stockStore\".data-storedata.{0,200}/gisx) { 
		
				#print "STATUS $&\n";
				my @n1 = split (/:/, $&);
				my @n2 = split (/\}/, $n1[1]);
		
				$statusv2 = $n2[0];
				$statusv2 =~ s/^\s*(.*?)\s*$/$1/;
			
				#print "AERS $statusv2\n\n";
			
				if ($statusv2 eq '0') {
				
					$statusv2 = "NO DISPONIBLE";
				
				}
			
				else { $statusv2 = "DISPONIBLE"; }
				
			}
	}
	elsif ( $dominio[1] eq 'dperfumes') {
						
		while ($htmltxt =~ /itemprop.\"name\".{0,50}/gisx) { 
		
			#print "\n\n$&\n\n";
			my @n1 = split (/\</, $&);
			my @n2 = split (/\>/, $n1[0]);
		
			$prodv2 = $n2[1];
			$prodv2 =~ s/^\s*(.*?)\s*$/$1/;
				
		}
	
		while ($htmltxt =~ /itemprop.\"brand\".{0,50}/gisx) { 
		
			#print "\n\n$&\n\n";
			my @n1 = split (/\</, $&);
			my @n2 = split (/\>/, $n1[0]);
		
			$marcav2 = $n2[1];
			$marcav2 =~ s/^\s*(.*?)\s*$/$1/;
			
		}
	
		while ($htmltxt =~ /\<span.class\=\"price-\".{0,100}/gisx) { 
		
			#print "\n\n$&\n\n";
			my @n1 = split (/\"/, $&);
			my @n2 = split (/\"/, $n1[1]);
		
			$pricev2 = $n2[0];
			$pricev2 =~ s/^\s*(.*?)\s*$/$1/;
			
			#my @n3 = split (/\./, $pricev2);
			#$pricev2 = $n3[0];
			$pricev2 =~ s/\D//g;
				
		}
		
		if ($pricev2 eq "") {
			
			while ($htmltxt =~ /\<span.class\=\"price-new\".{0,100}/gisx) { 
		
				#print "\n\n$&\n\n";
				my @n1 = split (/\"/, $&);
				my @n2 = split (/\"/, $n1[1]);
		
				$pricev2 = $n2[0];
				$pricev2 =~ s/^\s*(.*?)\s*$/$1/;
			
				#my @n3 = split (/\./, $pricev2);
				#$pricev2 = $n3[0];
				$pricev2 =~ s/\D//g;
			
			}
			
		}
		
		if ($pricev2 eq "") {
			
			while ($htmltxt =~ /\<span.class\=\"price-old\".{0,100}/gisx) { 
		
				#print "\nULTIMO\n$&\n\n";
				my @n1 = split (/\</, $&);
				
				#print "0 $n1[0]\n";
				#print "1 $n1[1]\n";		
				#print "2 $n1[2]\n";						
				
				my @n2 = split (/\>/, $n1[2]);
		
				$pricev2 = $n2[1];
				$pricev2 =~ s/^\s*(.*?)\s*$/$1/;
			
				#my @n3 = split (/\./, $pricev2);
				#$pricev2 = $n3[0];
				$pricev2 =~ s/\D//g;
			
			}
			
		}
		
		$statusv2 = "NO DISPONIBLE";
		
		while ($htmltxt =~ /\<input.class\=\"button-product-page".{0,1}/gisx) { 
		
			#print "\n\n$&\n\n";
		
			$statusv2 = "DISPONIBLE";
	
		}
		
		
	}
	
	elsif ( $dominio[1] eq 'falabella') {
		
		while ($htmltxt =~ /itemprop.\"name\".{0,50}/gisx) { 
		
			#print "$&\n";
			my @n1 = split (/\</, $&);
			my @n2 = split (/\>/, $n1[0]);
		
			$prodv2 = $n2[1];
			$prodv2 =~ s/^\s*(.*?)\s*$/$1/;
				
		}
	
		while ($htmltxt =~ /itemprop.\"brand\".{0,50}/gisx) { 
		
			#print "$&\n";
			my @n1 = split (/\</, $&);
			my @n2 = split (/\>/, $n1[0]);
		
			$marcav2 = $n2[1];
			$marcav2 =~ s/^\s*(.*?)\s*$/$1/;
			
		}
	
		while ($htmltxt =~ /meta.content.{0,15}itemprop.\"price\"/gisx) { 
		
			#print "$&\n";
			my @n1 = split (/\"/, $&);
			my @n2 = split (/\"/, $n1[1]);
		
			$pricev2 = $n2[0];
			$pricev2 =~ s/^\s*(.*?)\s*$/$1/;
			
			my @n3 = split (/\./, $pricev2);
			$pricev2 = $n3[0];
			$pricev2 =~ s/\D//g;
				
		}
		
		$statusv2 = "NO DISPONIBLE";
		
		while ($htmltxt =~ /addItemToCartBtn/gisx) { 
		
			$statusv2 = "DISPONIBLE";
	
		}
		
		
	}
	
	$priceant = `/bin/cat $filecmp | grep $URL[1] | head -1 | cut -d';' -f11`;
	$priceant =~s/\D//g;
	
	if ($pricev2 eq $priceant) {
		
		$dif = "";
	}
	
	else {
		
		$dif = "*";
		$haycambios++;
		
	}
	
	debug("Comercio    Nombre Producto  ", $prodva);
	debug("Comercio    Marca Producto   ", $marcava);
	debug("Comercio    Precio Producto  ", $priceva);
	
	debug("Competidor   Nombre Producto  ", $prodv2);
	debug("Competidor   Marca Producto   ", $marcav2);
	debug("Competidor   Precio Producto  ", $pricev2);
	debug("Competidor   Precio Anterior  ", $priceant);
	debug("Competidor   Disponibilidad   ", $statusv2);

	debug("blank");
	
	print LOG "$date;$URL[0];Comercio;$prodva;$marcava;$priceva;$URL[1];$dominio[1];$prodv2;$marcav2;$pricev2;$priceant;$statusv2;$dif\n";	
	
	$i++;

}

close LOG;

my $horafin = strftime "%Y.%m.%d / %H.%M.%S", localtime;

if ($haycambios == 0) {
	
	debug("No hay cambios de precio", $dif);
	
}

else {
	
	debug("Cambios de precio :", $haycambios);
	
}

debug("Hora Inicio       :", $horainicio);
debug("Hora de Fin       :", $horafin);
debug("blank");

my $x = `/bin/cp $filelog tmp.csv`;
