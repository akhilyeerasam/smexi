package HK::GenericImporter;

use strict;
use warnings;
use Carp;
use Data::Dumper;

# switch all standard streams to UTF-8
use open qw(:std :utf8);

use HK::BaseUtils qw(isNotEmpty trim getContentOfFileAsOneStringWithEncodingParameter);
use HK::ImportParameterManager;
use HK::JsonHandler;
use HK::CsvHandler;
use base qw(HK::ImportParameterManager);

#############################################################################
# Constructor of class GenericImporter
# Generic means: this importer can import from csv or json files (switched by commandline options)
#
sub new {
  my $class = shift;
  my $self  = $class->SUPER::new();

  $self->_init( @_ );

  return $self;
}

#############################################################################
sub _init {
  my $self = shift;
  
  $self->{_hooks} = [];
  $self->{_dataHandler} = undef;

  my %additionalParameters = @_;

  while ( my( $key, $value ) = each %additionalParameters ) {
      $self->{$key} = $value;
  }

}

#############################################################################
sub getListOfAllFields {
  my $self = shift;
  return( $self->{_dataHandler}->getListOfAllFields() );
}
#############################################################################
sub getUsageString {
    my ( $self ) = @_;
    my( $parentUsageString ) = $self->SUPER::getUsageString();
    my $errorString = <<"EOTEXT";
Please specify at least one data import file as regular parameter.

Possible import options are:

$parentUsageString
EOTEXT
    return( $errorString );
}
#############################################################################
sub clone {
    my ( $self ) = shift;
    my $clone = HK::GenericImporter->new();
    # the following two statements are okay for cloning but bad otherwise
    $clone->_initFromHash( $self );
    $clone->{_dataHandler} = $self->{_dataHandler}->clone();
    return( $clone );
}
#############################################################################
sub initFromCommandlineParameters {
  my ( $self, $referenceToAllParameters ) = @_;

  # Initialize underlying ImportParameterManager
  my( $wasOkay ) = $self->SUPER::initFromCommandlineParameters( $referenceToAllParameters );

  if ( $wasOkay ) {
    # Initialize used JsonHandler
    if ( @$referenceToAllParameters > 0 ) {
      if ( $self->{inputDataType} eq "json" ) {
	$self->{_dataHandler} = HK::JsonHandler->new( encoding => $self->{encoding}, processingMode => $self->{processingMode},
						      inputFiles => $referenceToAllParameters, dataIsInField => $self->{dataIsInField} );
      }
      else {
	$self->{_dataHandler} = HK::CsvHandler->new( encoding => $self->{encoding}, processingMode => $self->{processingMode},
						     separatorCharacter => $self->{separatorCharacter},
						     inputFiles => $referenceToAllParameters );
      }
    }
    else {
      print STDERR "** Error: No input files specified\n\n";
      $wasOkay = 0;
    }
  }

  return( $wasOkay );
}
#############################################################################
sub startProcessing {
  my $self = shift;

  my $howManyProcessed = 0;

  for (;;) {

    my $processed = $self->_handleNextInputElement();

    if ( $processed < 0 ) {
      print STDERR "End of data reached. Have processed $howManyProcessed entries in total. Will finish now\n";
      last;
    }

    $howManyProcessed += $processed;
    if ( $howManyProcessed >= $self->{maxNumberOfInserts} ) {
      print STDERR "Have processed $howManyProcessed entries in total. Will finish now\n";
      last;
    }
    else {
      $self->log( 89, "* $howManyProcessed elements handled in total (<" . $self->{maxNumberOfInserts} . ")\n" );
    }

    if ( $howManyProcessed > 0 and $howManyProcessed % $self->{blockSize} == 0 ) {
      print STDERR "Have processed " . $self->{blockSize} . " elements. Will sleep for " . $self->{sleepingDuration} .
	" seconds, so not to overload destination system\n";
      sleep( $self->{sleepingDuration} );
    }
  }
}

#############################################################################
sub log {
  my ( $self, $level, $toPrint ) = @_;
  if ( $level <= $self->{verbosity} ) {
    print STDERR $toPrint;
  }
}
#############################################################################
sub _handleNextInputElement {
  my ( $self ) = @_;
  my $numberOfHandledEntries = 0;

  my $nextInputElement = $self->{_dataHandler}->getNextElementFromInputFiles();

  if ( defined( $nextInputElement ) ) {

    $self->checkStartingPoint( $nextInputElement ) unless $self->isStartingPointReached();

    if ( $self->isStartingPointReached() ) {
      $self->_handleOneEntry( $nextInputElement, $self );
      $numberOfHandledEntries++;
    }
  }
  else {
    # Nothing left
    $numberOfHandledEntries = -1;
  }

  return( $numberOfHandledEntries );
}
#############################################################################
sub _handleOneEntry {
  my ( $self, $perlInstance, $importParameterManager ) = @_;
  my $processed = 1;

  foreach my $hook ( @{ $self->{_hooks} } ) {
    $hook->( $perlInstance, $self );
  }
  return( $processed );
}
#############################################################################
# addHandler will add a hook to be called for each entry found in the input files
# The handler will get the following parameters:
#   $perlInstance, $aloeClient, $blockSize, $sleepingDuration, $testMode, $groupId, $groupsToShareTo, $fileHashReference
sub addHandler {
  my ( $self, $hook ) = @_;
  push( @{ $self->{_hooks} }, $hook );
}

#############################################################################
# addHookForNewFile will add a hook to be called each time the importer
# switches to the next input file
# The hook will get the fileName as parameter
sub addHookForNewFile {
    my ( $self, $hook ) = @_;
    $self->{_dataHandler}->addHookForNewFile( $hook );
}


1;
