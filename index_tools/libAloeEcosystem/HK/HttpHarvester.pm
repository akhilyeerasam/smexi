package HK::HttpHarvester;

use strict;
use warnings;
use Carp;
use Data::Dumper;
#use Error qw(:try);

use LWP::UserAgent;
use XML::XPath;
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
    
    $self->{url} = shift;
    $self->{dataType} = shift;
    
    #my %additionalParameters = @_;

    #while ( my( $key, $value ) = each %additionalParameters ) {
    #    $self->{$key} = $value;
    #}

    #throw Error::Simple( "Error initializing HttpHarvester" );
}
#############################################################################
sub setUrl {
    my ( $self, $newValue ) = @_;
    $self->{url} = $newValue;
}
#############################################################################
sub retryIfReturnCodeIsAfterXSeconds {
    my ( $self, $returnCode, $secondsToSleep ) = @_;
    
    $self->{sleepingDurations} = {} unless exists( $self->{sleepingDurations} );
    $self->{sleepingDurations}->{$returnCode} = $secondsToSleep;
}
#############################################################################
sub harvestData {
    my $self = shift;
    my $result = undef;    # result will be of different type depending on the dataType specified in constructor

    my $userAgent = LWP::UserAgent->new( timeout => 25 );
    my @errorList = ();

    # use show_progress for debugging purposes
    #$userAgent->show_progress(1);
    #$userAgent->max_redirect(4);
    
    my $request = HTTP::Request->new( GET => $self->{url} );

    my $response = $userAgent->request( $request );

    if ( defined( $response ) ) {
        if ( $response->is_success ) {
            # URI was okay. Do nothing
            # print "Final URI = " . $response->request()->uri() . "\n";
            my $content = $response->content;
            #print STDOUT "Got content:\n", $content, "\n";
            if ( $self->{dataType} eq 'xml' ) {
                $result = $self->_extractXml( $content );
            }
            elsif ( $self->{dataType} eq 'json' ) {
                $result = $self->_extractJson( $content );
            }
            else {
                die "Unsupported data type '", $self->{dataType}, "\n";
            }
        }
        elsif ( $response->is_redirect ) {
            # redirect, okay!
        }
        else {
            my $responseCode = $response->code;
            if ( exists( $self->{sleepingDurations} ) and exists( $self->{sleepingDurations}->{$responseCode} ) ) {
                sleep( $self->{sleepingDurations}->{$responseCode} );
                # try again
                return( $self->harvestData() );
            }
            # fail
            my $message = status_message( $responseCode );
            print STDERR "Harvesting data via ", $self->{url}, " failed with code ", $responseCode, ": ", $message, "\n";
        }
    }
    else {
        # fail
        print STDERR "Harvesting data via ", $self->{url}, " failed\n"
    }

    return( $result );
}
#############################################################################
sub _extractXml {
    my ( $self, $xmlDataAsString ) = @_;
    my $xmlPathInstance = XML::XPath->new( xml => $xmlDataAsString );
    return( $xmlPathInstance );
}

#############################################################################
sub _extractJson {
    my ( $self, $jsonDataAsString ) = @_;

    #my $decoder = JSON->new->ascii->allow_nonref;
    # If we get JSON data via HTTP request, we must use the utf8 option. ascii is the better choice if we
    # print data to STDIN/STDOUT streams that are switched to utf8 anyway
    my $decoder = JSON::XS->new->utf8->allow_nonref;
    my $jsonObject = $decoder->decode( $jsonDataAsString );
    
    return( $jsonObject );
}

1;
