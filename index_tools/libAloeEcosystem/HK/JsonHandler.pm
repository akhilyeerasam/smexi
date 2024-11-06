package HK::JsonHandler;

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case :config pass_through :config no_auto_abbrev);
use Data::Dumper;

use File::Basename;

# switch all standard streams to UTF-8
use open qw(:std :utf8);

use JSON::XS;

use HK::BaseUtils qw(isNotEmpty trim getContentOfFileAsOneStringWithEncodingParameter);

# To export only selected functions (or variables), we derive
# from class 'Exporter', so the user can call method 'import()'
# of class 'Exporter'
use Exporter;
our @ISA = ( 'Exporter' );
# which functions to export by default? None. We prefer an OO interface
# so export of functions is probably not needed
our @EXPORT = qw();


#############################################################################
# Constructor of class JsonHandler
sub new {
  my $class = shift;
  my $self  = {};

  bless ($self, $class);
  $self->_init( @_ );

  return $self;
}
#############################################################################
sub clone {
    my $self = shift;

    my $options = {};
    $options->{processingMode} = $self->{processingMode};
    $options->{verbosity} = $self->{verbosity};  # in percent
    $options->{encoding} = $self->{encoding};
    $options->{dataIsInField} = $self->{dataIsInField};

    my @copyOfFileList;
    foreach my $fileToProcess ( @{ $self->{inputFiles} } ) {
        push( @copyOfFileList, $fileToProcess );
    }
    $options->{inputFiles} = \@copyOfFileList;

    my $clone = HK::JsonHandler->new( %$options );
    return( $clone );
}
#############################################################################

sub _init {
  my $self = shift;
  my %argumentsAsHash = @_;

  $self->{inputFiles} = [];
  $self->{_hooksIfNewFile} = [];
  $self->{_jsonCoder} = JSON::XS->new->pretty->allow_nonref;

  foreach my $key ( keys %argumentsAsHash ) {
    my $value = $argumentsAsHash{$key};
    if ( $key eq "inputFile" ) {
      push( @{ $self->{inputFiles} }, $argumentsAsHash{$key} );
    }
    elsif ( $key eq "inputFiles" ) {
      if ( ! ref( $argumentsAsHash{$key} ) eq "ARRAY" ) {
	die "Error! Configuration key 'inputFiles' must provide an array reference as value\n";
      }
      $self->{$key} = $argumentsAsHash{$key}
    }
    else {
      # Note: keys starting with underscore are not intended to be user defined!
      $self->{$key} = $argumentsAsHash{$key} unless $key =~ m/^_/;
    }
  }

  # Init default values
  # Possible values: incremental or inMemory
  $self->{processingMode} = "inMemory" unless defined( $self->{processingMode} );
  $self->{verbosity} = 0 unless defined( $self->{verbosity} );  # in percent
  $self->{encoding} = "utf8" unless defined( $self->{encoding} );
  $self->{dataIsInField} = undef unless defined( $self->{dataIsInField} );

  $self->{_inMemoryStructure} = undef;
  $self->{_currentIncrementalStream} = undef;
  $self->{_readBuffer} = undef;
  $self->{_processingFinished} = @{ $self->{inputFiles} } == 0 ? 1 : 0;
}

#############################################################################
# We don't know the names of all fields, so we return undef
sub getListOfAllFields {
  my $self = shift;
  return( () );
}
#############################################################################
sub log {
  my ( $self, $level, $toPrint ) = @_;
  if ( $level <= $self->{verbosity} ) {
    print STDERR $toPrint;
  }
}

#############################################################################
sub getNextElementFromInputFiles {
  my $self = shift;

  if ( ! defined( $self->{_inMemoryStructure} ) and
       ! defined( $self->{_currentIncrementalStream} ) ) {
    # initialize processing
    $self->_initializeProcessing();
  }

  if ( ! $self->{_processingFinished} ) {
    if ( $self->{processingMode} eq "inMemory" ) {
      my $nextElement = shift( @{ $self->{_inMemoryStructure} } );

      $self->_prepareNextReadingProcessForInMemoryProcessing();

      return( $nextElement );
    }
    else {
      return( $self->_incrementalRead() );
    }
  }

  return( undef );
}

#############################################################################
sub _initializeProcessing {
  my $self = shift;

  if ( ! defined( $self->{_inMemoryStructure} ) and
       ! defined( $self->{_currentIncrementalStream} ) ) {

    if ( $self->{processingMode} eq "inMemory" ) {
      $self->_readNextInputFileForInMemoryProcessing();

      $self->_prepareNextReadingProcessForInMemoryProcessing();
    }
    else {
      # Incremental mode: open first file and try to parse incremental
      $self->_openNextFileForIncrementalReading();
    }
  }
}

#############################################################################
# Make sure the next access to _inMemoryStructure will return the next element (if any)
sub _prepareNextReadingProcessForInMemoryProcessing {
    my $self = shift;
    
    while ( @{ $self->{inputFiles} } > 0 and @{ $self->{_inMemoryStructure} } == 0 ) {
	$self->_readNextInputFileForInMemoryProcessing();
	$self->log( 30, $self->{_currentInputFile} . " is empty!" ) if @{ $self->{_inMemoryStructure} } == 0;
    }
}
#############################################################################
sub _readNextInputFileForInMemoryProcessing {
  my $self = shift;

  if ( @{ $self->{inputFiles} } > 0 ) {
      my $jsonFile = $self->_getNextFile();

      #print "*** Will open and process $jsonFile\n";

      if ( defined( $jsonFile ) ) {
	  # read content of first file into a single structure, store in $self->{_inMemoryStructure}
	  my $jsonString = getContentOfFileAsOneStringWithEncodingParameter( $jsonFile, $self->{encoding} );
	  $self->{_inMemoryStructure} = $self->{_jsonCoder}->decode( $jsonString );


	  if ( ref( $self->{_inMemoryStructure} ) ne "ARRAY" ) {
	      if ( defined( $self->{dataIsInField} ) ) {
		  if ( ref( $self->{_inMemoryStructure} ) eq "HASH" ) {
		      my $arrayCandidate = $self->_getArrayContainingData( $self->{_inMemoryStructure}, $self->{dataIsInField} );
		      if ( defined( $arrayCandidate and ref( $arrayCandidate ) eq "ARRAY" ) ) {
			  $self->{_inMemoryStructure} = $arrayCandidate;
		      }
		      else {
			  die "Field '" . $self->{dataIsInField} . "' of toplevel element of json data is not an array\n";
		      }
		  }
		  else {
		      die "Toplevel element of json data is not a HASH, so we can't access the specified field: " . ref( $self->{_inMemoryStructure} ) . "\n";
		  }
	      }
	      else {
		  die "Toplevel element of json data is not an array : " . ref( $self->{_inMemoryStructure} ) . "\n";
	      }
	  }
      }
  }
}

#############################################################################
sub _getArrayContainingData {
    my( $self, $searchHere, $toSearch ) = @_;
    my $structureToSearch = $searchHere;
    my $arrayCandidate = undef;

    my @allPaths = split( /\//, $toSearch );
    while( @allPaths > 0 ) {
	if ( @allPaths > 0 and ref( $structureToSearch ne "HASH" ) ) {
	    die "Specified path of json data could not be found\n";
	}
	my $currentPath = shift( @allPaths );
	$arrayCandidate = $structureToSearch->{$currentPath};
	$structureToSearch = $arrayCandidate;
    }
    return( $arrayCandidate );
}

#############################################################################
sub _getNextFile {
  my $self = shift;

  my $nextInputFile = shift( @{ $self->{inputFiles} } );
  $self->{_currentInputFile} = $nextInputFile;
  return( $nextInputFile );
}
#############################################################################
sub _openNextFileForIncrementalReading {
  my $self = shift;

  if ( @{ $self->{inputFiles} } > 0 ) {
    my $nextFile = shift( @{ $self->{inputFiles} } );

    close( $self->{_currentIncrementalStream} ) if defined( $self->{_currentIncrementalStream} );
    
    # Call the hooks to be called, when a new file is opened (if any)
    $self->_callHooksForNewFile( $nextFile );
    
    # open the big file
    open $self->{_currentIncrementalStream}, "<$nextFile" or die "Could not open $nextFile: $!";

    # first parse the initial "["
    for (;;) {
      sysread $self->{_currentIncrementalStream}, $self->{_readBuffer}, 65536 or die "read error: $!";
      $self->{_jsonCoder}->incr_parse( $self->{_readBuffer} );	# void context, so no parsing

      # Exit the loop once we found and removed(!) the initial "[".
      # In essence, we are (ab-)using the $self->{_jsonCoder} object as a simple scalar
      # we append data to.
      last if $self->{_jsonCoder}->incr_text =~ s/^ \s* \[ //x;
    }
  }
}
#############################################################################
sub _incrementalRead {
  my $self = shift;
  my $foundObject = undef;

  # in this loop we read data until we got a single JSON object
  for (;;) {


    if ( my $object = $self->{_jsonCoder}->incr_parse ) {
      # do something with $object
      $foundObject = $object;
      $self->log( 100, "Found next object\n" );
      last;
    }
    else {
      # add more data
      sysread $self->{_currentIncrementalStream}, $self->{_readBuffer}, 65536 or die "read error: $!";
      $self->{_jsonCoder}->incr_parse ($self->{_readBuffer});	# void context, so no parsing
    }
  }

  if ( defined( $foundObject ) ) {
    $self->_skipToNextInputObject();
  }

  return( $foundObject );
}
#############################################################################
sub _skipToNextInputObject {
  my $self = shift;

  # in this loop we read data until we either found and parsed the
  # separating "," between elements, or the final "]"
  for (;;) {
    # first skip whitespace
    $self->{_jsonCoder}->incr_text =~ s/^\s*//;

    # if we find "]", we are done
    if ($self->{_jsonCoder}->incr_text =~ s/^\]//) {
      # file is finished. Skip to next file (if any)
      if ( @{ $self->{inputFiles} } > 0 ) {
	$self->log( 50, "Finished current file. Will find next\n" );
	$self->_openNextFileForIncrementalReading();
      }
      else {
	$self->log( 30, "Last input file is finished\n" );
	$self->{_processingFinished} = 1;
      }
      last;
    }

    # if we find ",", we can continue with the next element
    if ($self->{_jsonCoder}->incr_text =~ s/^,//) {
      last;
    }

    # if we find anything else, we have a parse error!
    if (length $self->{_jsonCoder}->incr_text) {
      die "parse error near ", $self->{_jsonCoder}->incr_text;
    }

    # else add more data
    sysread $self->{_currentIncrementalStream}, $self->{_readBuffer}, 65536 or die "read error: $!";
    $self->{_jsonCoder}->incr_parse ($self->{_readBuffer});	# void context, so no parsing
  }
}


#############################################################################
sub _callHooksForNewFile {
    my ( $self, $fileName ) = @_;
    foreach my $hook ( @{ $self->{_hooksIfNewFile} } ) {
        $hook->( $fileName );
    }
}
#############################################################################
sub addHookForNewFile {
    my ( $self, $hook ) = @_;
    push( @{ $self->{_hooksIfNewFile} }, $hook );
}


1;
