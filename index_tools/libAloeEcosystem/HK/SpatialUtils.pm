package HK::SpatialUtils;

use strict;
use warnings;
use Carp;
#use utf8;  # only needed, if we have an umlaut in our source code

use URI::Escape;

# To export only selected functions (or variables), we derive
# from class 'Exporter', so the user can call method 'import()'
# of class 'Exporter'
use Exporter;
our @ISA = ( 'Exporter' );
# which functions to export by default?
our @EXPORT = qw();
# which functions to export byuser request?
our @EXPORT_OK = qw(getLocationViaNominatim);



#############################################################################
# Try to get latitude and longitude of a given place description.

# Arguments:
#   $userAgent  an instance of LWP::UserAgent
#   $placeDescription  an object with optional fields 'postalcode', 'street', 'city' and 'country'
# Note:
#   - street is expected to be of the form "housenumber street"
#   - the fields inside $placeDescription are used as URL GET parameters and will thus be escaped
#
# Returned is a pair ( $returnCode, $returnValue ) where $returnValue is:
#  an object with fields "lat" and "lon" if $returnCode == 1 
#  an object with fields "lat" and "lon" set to 0.0 if $returnCode == 0
#  an error string if $returnCode < 0 (that is: the URL request failed and the reason is described in $returnValue)
#
# **** Please note: the nominatim usage policy tells you not to exceed the limit of 1 requests per second!! Additionally
#                   a request may fail for unknown reasons with return code 500. In that case you can try to insert
#                   another sleep and then resend the request!
sub getLocationViaNominatim {
    my( $userAgent, $placeDescription ) = @_;
    my $returnedValue = undef;
    my $returnCode = -1;

    my $url = "https://nominatim.openstreetmap.org/search?format=json";
    if ( $placeDescription->{postalcode} ) {
        $url .= "&postalcode=" . uri_escape_utf8( $placeDescription->{postalcode} );
    }
    if ( $placeDescription->{country} ) {
        $url .= "&country=" . uri_escape_utf8( $placeDescription->{country} );
    }
    if ( $placeDescription->{street} ) {
        $url .= "&street=" . uri_escape_utf8( $placeDescription->{street} );
    }
    if ( $placeDescription->{city} ) {
        $url .= "&city=" . uri_escape_utf8( $placeDescription->{city} );
    }
    #my $url = "https://nominatim.openstreetmap.org/search?street=${streetToUse}&postalcode=${postleitzahl}&country=germany&format=json";
    my $request = HTTP::Request->new( GET => $url );
    my $response = $userAgent->request( $request );
    
    if ( defined( $response ) ) {
        if ( $response->is_success ) {

            my $jsonCoder = JSON::XS->new->pretty->allow_nonref;
            my $responseStructure = $jsonCoder->decode( $response->content );
            if ( @$responseStructure > 0 ) {
                my $x = $responseStructure->[0];

                $returnCode = 1;
                $returnedValue = { "lat" => $x->{lat}, "lon" => $x->{lon} };
            }
            else {
                $returnCode = 0;
                $returnedValue = { "lat" => 0.0, "lon" => 0.0 };
            }
            
        }
        elsif ( $response->is_redirect ) {
            $returnedValue = "Fail: '$url' is a redirect\n";
        }
        else {
            $returnedValue = "NOT Okay: URL '$url' is unreachable. Status is " . $response->code . "\n" . "Status line: " . $response->status_line . "\n";
        }
    }
    else {
        $returnedValue = "Error: " . $response->status_line . "\n";
    }
    
    return( $returnCode, $returnedValue );
}

#############################################################################
# Try to get latitude and longitude of a place given by a description string.

# Arguments:
#   $userAgent  an instance of LWP::UserAgent
#   $placeDescription  a string to be used as place description. The description string can be segmented via
#                      commas to enhance accuracy. Sample strings:
#                           almenweg,kaiserslautern
#                           kaiserslautern,almenweg
#                           Bännjerrückschule,kaiserslautern
#
# Returned is a pair ( $returnCode, $returnValue ) where $returnValue is:
#  an object with fields "lat" and "lon" if $returnCode == 1 
#  an object with fields "lat" and "lon" set to 0.0 if $returnCode == 0
#  an error string if $returnCode < 0 (that is: the URL request failed and the reason is described in $returnValue)
#
# **** Please note: the nominatim usage policy tells you not to exceed the limit of 1 requests per second!! Additionally
#                   a request may fail for unknown reasons with return code 500. In that case you can try to insert
#                   another sleep and then resend the request!
sub getLocationViaNominatimGenericQuery {
    my( $userAgent, $placeDescription ) = @_;
    my $returnedValue = undef;
    my $returnCode = -1;

    my $url = "https://nominatim.openstreetmap.org/search?format=json";
    if ( $placeDescription->{postalcode} ) {
        $url .= "&postalcode=" . uri_escape_utf8( $placeDescription->{postalcode} );
    }
    if ( $placeDescription->{country} ) {
        $url .= "&country=" . uri_escape_utf8( $placeDescription->{country} );
    }
    if ( $placeDescription->{street} ) {
        $url .= "&street=" . uri_escape_utf8( $placeDescription->{street} );
    }
    if ( $placeDescription->{city} ) {
        $url .= "&city=" . uri_escape_utf8( $placeDescription->{city} );
    }
    #my $url = "https://nominatim.openstreetmap.org/search?street=${streetToUse}&postalcode=${postleitzahl}&country=germany&format=json";
    my $request = HTTP::Request->new( GET => $url );
    my $response = $userAgent->request( $request );
    
    if ( defined( $response ) ) {
        if ( $response->is_success ) {

            my $jsonCoder = JSON::XS->new->pretty->allow_nonref;
            my $responseStructure = $jsonCoder->decode( $response->content );
            if ( @$responseStructure > 0 ) {
                my $x = $responseStructure->[0];

                $returnCode = 1;
                $returnedValue = { "lat" => $x->{lat}, "lon" => $x->{lon} };
            }
            else {
                $returnCode = 0;
                $returnedValue = { "lat" => 0.0, "lon" => 0.0 };
            }
            
        }
        elsif ( $response->is_redirect ) {
            $returnedValue = "Fail: '$url' is a redirect\n";
        }
        else {
            $returnedValue = "NOT Okay: URL '$url' is unreachable. Status is " . $response->code . "\n" . "Status line: " . $response->status_line . "\n";
        }
    }
    else {
        $returnedValue = "Error: " . $response->status_line . "\n";
    }
    
    return( $returnCode, $returnedValue );
}
#############################################################################

1;
