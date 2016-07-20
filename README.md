# comparaPrecios
# comparador de precios desarrollado en Perl
# 
# Para ejecutar el comparador es necesario instalar CPAN
# 
# Antes de ejecutar el programa se deben instalar adicionales al ambiente perl para esto desde la consola instalar:
# 
# 
# > install LWP::Simple
# 
# las librerias que debemos instalar son:
# 
# LWP::Simple;
# LW::UserAgent;
# HTTP::Request::Commen qw(GET);
# XML::Simple;
# Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
# WWW::Mechanize;
# HTML::HeadParser;
# POSIX qw(strftime);
# Encode qw(decode encode);
# MIME::Base64;
# File::Spec;
# LWP::MediaTypes;
# Net::FTP;
# 
# una vez instaladas las librerías, debemos tener un archivo de texto plano con las url a comparar, el formato del archivo debe # ser:
# 
# una línea por comparación, separadas por punto y coma tal como el siguiente ejemplo:
# 
# URL_COMERCIO;URL_COMPETENCIA;
# 
# Para ejecutar el comparador, desde la consola ejecutar la siguiente línea:
# 
# > perl -w comparador.perl <ARCHIVO_CON_URLS>
# 
# por ahora el comparador funciona con Falabella, Dafiti, Allnutrition, Linio, Dperfumes.
# 
#  
