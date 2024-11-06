package HK::ImportParameterManager;

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case :config pass_through :config no_auto_abbrev);
use Data::Dumper;

use File::Basename;
use HK::BaseUtils qw(isNotEmpty trim);

# switch all standard streams to UTF-8
use open qw(:std :utf8);

our $AUTOLOAD;  # it's a package global

# To export only selected functions (or variables), we derive
# from class 'Exporter', so the user can call method 'import()'
# of class 'Exporter'
use Exporter;
our @ISA = ( 'Exporter' );
# which functions to export by default? None. We prefer an OO interface
# so export of functions is probably not needed
our @EXPORT = qw();


#############################################################################
# Constructor of class ImportParameterManager
sub new {
    my $class = shift;
    my $self  = {};

    bless ($self, $class);

    return $self;
}
#############################################################################
sub _initFromHash {
    my ( $self, $initializationHash ) = @_;

    $self->{dataIsInField} = $initializationHash->{dataIsInField};
    $self->{maxNumberOfInserts} = $initializationHash->{maxNumberOfInserts};
    $self->{blockSize} = $initializationHash->{blockSize};
    $self->{sleepingDuration} = $initializationHash->{sleepingDuration};
    $self->{verbosity} = $initializationHash->{verbosity};
    $self->{encoding} = $initializationHash->{encoding};
    $self->{_isStartingPointReached} = $initializationHash->{_isStartingPointReached};
    $self->{inputDataType} = $initializationHash->{inputDataType};
    $self->{processingMode} = $initializationHash->{processingMode};
}
#############################################################################

sub initFromCommandlineParameters {
    my $self = shift;
    my $commandLineArguments = shift;

    $self->{baseImporter} = undef;
    $self->{hooks} = [];

    my( $wasOkay, $helpString ) = $self->checkCommandLine( $commandLineArguments );

    if ( $wasOkay ) {
      # Init default values
      $self->{dataIsInField} = undef unless defined( $self->{dataIsInField} );
      $self->{maxNumberOfInserts} = 100000000 unless defined( $self->{maxNumberOfInserts} );
      $self->{blockSize} = 20 unless defined( $self->{blockSize} );
      $self->{sleepingDuration} = 40 unless defined( $self->{sleepingDuration} );
      $self->{verbosity} = 0 unless defined( $self->{verbosity} );
      $self->{encoding} = "utf8" unless defined( $self->{encoding} );
      $self->{_isStartingPointReached} = defined( $self->{_startingPointKey} ) ? 0 : 1;
      $self->{inputDataType} = "json" unless defined( $self->{inputDataType} );
      unless ( defined( $self->{processingMode} ) ) {
	$self->{processingMode} = $self->{inputDataType} eq "json" ? "inMemory" : "incremental";
      }

      if ( $self->{inputDataType} eq "csv" and $self->{processingMode} eq "inMemory" ) {
	warn "Illegal combination of processing mode " . $self->{processingMode} . " and input data type " . $self->{inputDataType} .
	  ". Will switch to processing mode 'incremental' instead\n";
	$self->{processingMode} = "incremental";
      }
    }

    return( $wasOkay, $helpString );
}

#############################################################################
sub getStartingPointKey {
  my $self = shift;
  return( $self->{_startingPointKey} );
}
#############################################################################
sub getStartingPointValue {
  my $self = shift;
  return( $self->{_startingPointValue} );
}
#############################################################################
sub setStartingPoint {
  my ( $self, $newValue ) = @_;

  my $wasSuccessful = 0;

  if ( $newValue =~ m/^(.*)?:(.*)$/ ) {
    my( $startingPointKey, $startingPointValue ) = ( trim( $1 ), trim( $2 ) );

    if ( isNotEmpty( $startingPointKey ) and isNotEmpty( $startingPointValue ) ) {
      $self->{_startingPointKey} = $startingPointKey;
      $self->{_startingPointValue} = $startingPointValue;
      $self->{_isStartingPointReached} = 0;
      $wasSuccessful = 1;
    }
  }

  return( $wasSuccessful );
}
#############################################################################
sub isStartingPointReached {
  my $self = shift;
  return( $self->{_isStartingPointReached} );
}


#############################################################################
sub checkStartingPoint {
  my ( $self, $element ) = @_;

  if ( defined( $self->getStartingPointKey() ) ) {
    my ( $fieldName, $fieldValue ) = ( $self->getStartingPointKey(), $self->getStartingPointValue() );
    if ( defined( $element->{$fieldName} ) and $element->{$fieldName} =~ m/$fieldValue/ ) {
      $self->{_isStartingPointReached} = 1;
    }
  }
  else {
    # this should not happen due to method setStartingPoint()
    die "Illegal starting point specified\n";
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
sub getUsageString {
    my $errorString = <<"EOTEXT";
Import options: [-h|--help] [--importVerbosity <percentLevel>] [--maxNumberOfInserts <maxNumberOfInserts>] [--inputDataEncoding <encoding>] [--blockSize <blockSize>] [--sleepingDuration <seconds>] [--processingMode inMemory|incremental] [--inputDataType json|csv] [--startingPoint <specifier>] [--separatorCharacter <separator>] [--dataIsInField <fieldName>]

  Sleeping duration must be specified in seconds.
  Default maxNumberOfInserts is 100000000, default block size is 20, default sleepingDuration is 40 seconds.
  Default inputDataType is json.
  Option dataIsInField is used only for json data that is processed in memory. In this case the data is assumed to be located
    in the specified field of the toplevel element.
  To specify e.g. a tab as separator try something like: --separatorCharacter \$'\\t'
  Default processing mode is inMemory for input data type json and incremental for csv.
  Verbosity level should be given in percent (higher or lower values are mapped to 100 or 0 respectively, default: 0)
  Block size is the number of input resources to process before starting to sleep (default: 20).
  The starting point specifier must be of the form '<fieldName>:<fieldValue>'. The processing will then start at the first element
    found where the corresponding field value matches <fieldValue>.
Sample parameters:
  --importVerbosity 100 --inputDataType csv --maxNumberOfInserts 10 publications_2015_09_03.csv  (* test import process for 10 units *)
  --importVerbosity 100 --inputDataType json --startingPoint idField:abcUniqueId --dataIsInField listOfEntries data.json
  --importVerbosity 100 --inputDataType json --processingMode incremental data.json
EOTEXT
    return( $errorString );
}
#############################################################################
sub checkCommandLine {
    my ( $self, $arrayToCheck ) = @_;

    my ( $verbosity, $maxNumberOfInserts, $blockSize, $sleepingDuration, $startingPoint, $encoding, $processingMode, $inputDataType,
	 $separatorCharacter, $dataIsInField );
    my $helpMe;

    # Check command line
    if ( GetOptionsFromArray( $arrayToCheck,
			      "importVerbosity=i" => \$verbosity,
			      "dataIsInField=s" => \$dataIsInField,
			      "blockSize=i" => \$blockSize,
			      "inputDataEncoding=s" => \$encoding,
			      "inputDataType=s" => \$inputDataType,
			      "maxNumberOfInserts=i" => \$maxNumberOfInserts,
			      "sleepingDuration=i" => \$sleepingDuration,
			      "startingPoint=s" => \$startingPoint,
			      "processingMode=s" => \$processingMode,
			      "separatorCharacter=s" => \$separatorCharacter,
			      "h" => \$helpMe, "help" => \$helpMe ) ) {
	# okay
	if ( $helpMe ) {
	    # nothing else needed: don't check command line
	}
	else {
	    $self->{dataIsInField} = $dataIsInField if defined( $dataIsInField );
	    $self->{maxNumberOfInserts} = $maxNumberOfInserts if defined( $maxNumberOfInserts );
	    $self->{blockSize} = $blockSize if defined( $blockSize );
	    $self->{sleepingDuration} = $sleepingDuration if defined( $sleepingDuration );
	    $self->{verbosity} = $verbosity if defined( $verbosity );
	    $self->{encoding} = $encoding if defined( $encoding );
	    $self->{inputDataType} = $inputDataType if defined( $inputDataType );
	    $self->setStartingPoint( $startingPoint ) if defined( $startingPoint );
	    $self->{processingMode} = $processingMode if defined( $processingMode );
	    $self->{separatorCharacter} = $separatorCharacter if defined( $separatorCharacter );

	    if ( defined( $processingMode ) and not ( $processingMode eq "inMemory" or $processingMode eq "incremental" ) ) {
	      warn "Illegal value '$processingMode' for processing mode. Allowed values: inMemory | incremental\n";
	      $helpMe = 1;
	    }
	    if ( defined( $inputDataType ) and not ( $inputDataType eq "json" or $inputDataType eq "csv" ) ) {
	      warn "Illegal value '$inputDataType' for inputDataType. Allowed values: json | csv\n";
	      $helpMe = 1;
	    }

	    # check regular command line parameters
	}
    }
    else {
	$helpMe = 1;
    }

    #print Dumper( $self );

    if ( $helpMe ) {
      return( 0 );
    }
    else {
      return( 1 );
    }
}

1;

__END__

=head1 NAME

ImportParameterManager - Class to handle parameters for data import from JSON or CSV files.

=head1 SYNOPSIS

  my $parameterManager = ImportParameterManager->new();
  my @remainingArguments = $parameterManager->initFromCommandlineParameters( \@ARGV );

=head1 DESCRIPTION

This class allows you to easily handle the commandline parameters used to import data to an ALOE system. In general this class is not created directly but is used via its derived class GenericImporter.

=head1 CONSTRUCTOR

=over 8

=item B<new> ()

Create a new instance of ImportParameterManager. Default log level is set to 0.

=back

=head1 METHODS

=over 8

=item B<initFromCommandlineParameters> ( I<arrayReference> )

Initialize the module with the values from the array reference. Usually this will be a reference to @ARGV or a copy. The parameters for ImportParameterManager will be used to initialize the module and are removed from the array reference. All other arguments will remain in the array reference as is.

=item B<log> ( I<level>, I<message> )

Log the given message to STDERR if the current log level is greater or equal level. Do nothing otherwise.

=back

=head1 AUTHOR

Heinz Kirchmann <kirchman@dfki.uni-kl.de>
