package HK::RestManager;

use strict;
use warnings;
use Carp;
use Data::Dumper;
#use Error qw(:try);

use LWP::UserAgent;
use JSON::XS;
use HTTP::Status qw(:constants :is status_message);

# switch all standard streams to UTF-8
use open qw(:std :utf8);

#use HK::BaseUtils qw(isNotEmpty trim getContentOfFileAsOneStringWithEncodingParameter);

# To export only selected functions (or variables), we derive
# from class 'Exporter', so the user can call method 'import()'
# of class 'Exporter'
use Exporter;
our @ISA = ( 'Exporter' );
# which functions to export by default?
our @EXPORT = qw();
# which functions to export by user request?
our @EXPORT_OK = qw();

#############################################################################
# Constructor of class HttpHarvester
#   Expects two parameters:  the URL to use for harvesting and a function to use for converting the
#                            response into an array of objects (hashes)
#

sub new {
    my $class = shift;
    my $self  = {};

    bless ($self, $class);
    $self->_init( @_ );

    return $self;
}

#############################################################################
sub _init {
    my $self = shift;
    
    #$self->{dataType} = shift;
    
    $self->{_userAgent} = LWP::UserAgent->new( timeout => 25 );
    # some pages do not accept requests, if user agent is not set
    $self->{_userAgent}->agent( "Perl RestManager" );
    # Avoid problems with invalid or self signed certificates
    $self->{_userAgent}->ssl_opts( 'verify_hostname' => 0 );
    # we want to allow up to 4 redirects. If we set this to 0, automatic redirecting is disabled
    # and we have to handle it manually via $response->redirects()
    $self->{_userAgent}->max_redirect(4);
    # use show_progress for debugging purposes
    #$self->{_userAgent}->show_progress(1);
    
    # If we get JSON data via HTTP request, we must use the utf8 option. ascii is the better choice if we
    # print data to STDIN/STDOUT streams that are switched to utf8 anyway
    $self->{_jsonCoder} = JSON::XS->new->utf8->allow_nonref;
    
    #my %additionalParameters = @_;

    #while ( my( $key, $value ) = each %additionalParameters ) {
    #    $self->{$key} = $value;
    #}

    #throw Error::Simple( "Error initializing HttpHarvester" );
}
#############################################################################
sub sendPostRequestAndReturnJsonResponse {
    my ( $self, $url, $optionalBodyContent ) = @_;
    
    my $request = HTTP::Request->new( 'POST', "${url}" );
    $request->header( 'Accept' => 'application/json; charset=UTF-8' );
    $request->header( 'Content-Type' => 'application/json; charset=UTF-8' );
    
    my $toAdd = $self->{_jsonCoder}->encode( $optionalBodyContent ) if defined( $optionalBodyContent );
    $request->content( $toAdd ) if defined( $toAdd );
    
    my $response = $self->{_userAgent}->request( $request );
    
    return( $self->_checkResult( $response, $url, "POST" ) );
}
#############################################################################
sub sendGetRequestAndReturnJsonResponse {
    my ( $self, $url ) = @_;
    my $result = undef;
    
    my $request = HTTP::Request->new( GET => $url );
    #$request->header( 'Content-Type' => "application/json;charset=utf-8" );
    my $response = $self->{_userAgent}->request( $request );

    return( $self->_checkResult( $response, $url, "GET" ) );
}

#############################################################################
sub _checkResult {
    my ( $self, $response, $url, $requestType ) = @_;
    my $result = undef;
    
    if ( defined( $response ) ) {
        if ( $response->is_success ) {
            # URI was okay. Do nothing
            # print "Final URI = " . $response->request()->uri() . "\n";
            my $content = $response->content;
            #print STDOUT "Got content:\n", $content, "\n";
            $result = $self->{_jsonCoder}->decode( $content );
        }
        else {
            my $responseCode = $response->code;
            # fail
            my $message = status_message( $responseCode ) . " (" . $response->status_line . ")";
            print STDERR "Sending $requestType request to '", $url, "' failed with code ", $responseCode, ": ", $message, "\n";
        }
    }
    else {
        # fail
        print STDERR "Sending $requestType request to ", $url, " failed for unknown reasons\n"
    }

    return( $result );  
}


1;
