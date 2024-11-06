package HK::CsvHandler;

use strict;
use warnings;
use Carp;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case :config pass_through :config no_auto_abbrev);
use Data::Dumper;

use File::Basename;

# switch all standard streams to UTF-8
use open qw(:std :utf8);

use Text::CSV_XS;

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
# Constructor of class CsvHandler
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
    $options->{verbosity} = $self->{verbosity};  # in percent
    $options->{encoding} = $self->{encoding};
    $options->{separatorCharacter} = $self->{separatorCharacter};

    my @copyOfFileList;
    foreach my $fileToProcess ( @{ $self->{inputFiles} } ) {
        push( @copyOfFileList, $fileToProcess );
    }
    $options->{inputFiles} = \@copyOfFileList;

    my $clone = HK::CsvHandler->new( %$options );
    return( $clone );
}
#############################################################################

sub _init {
  my $self = shift;
  my %argumentsAsHash = @_;

  $self->{inputFiles} = [];
  $self->{_hooksIfNewFile} = [];

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
  $self->{verbosity} = 0 unless defined( $self->{verbosity} );  # in percent

  # hk: or better default iso-8859-1?
  $self->{encoding} = "utf8" unless defined( $self->{encoding} );
  $self->{separatorCharacter} = ";" unless defined( $self->{separatorCharacter} );

  $self->{_csvModule} = Text::CSV_XS->new ({ binary => 1, auto_diag => 1, sep_char => $self->{separatorCharacter} })
      or die "Cannot use CSV: ".Text::CSV_XS->error_diag ();
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
  my $nextElement = undef;

  if ( ! defined( $self->{_currentIncrementalStream} ) ) {
    # initialize processing
    $self->_initializeProcessing();
  }

  if ( ! $self->{_processingFinished} ) {
    $nextElement = $self->{_csvModule}->getline( $self->{_currentIncrementalStream} );
    if ( ! defined( $nextElement ) ) {
      $self->_openNextFileForIncrementalReading();
      if ( ! $self->{_processingFinished} ) {
	$nextElement = $self->{_csvModule}->getline( $self->{_currentIncrementalStream} );
      }
    }
  }

  if ( defined( $nextElement ) ) {
    my %resultHash;
    # tricky! We use the fact that a hash is basically a double array that consists of keys & values
    # From: http://paulpodolny.blogspot.de/2011/01/perlhowto-combine-two-arrays-into-hash.html
    @resultHash{@{ $self->{_columnNames }}} = @{ $nextElement };
    $nextElement = \%resultHash;
  }

  return( $nextElement );
}

#############################################################################
sub getListOfAllFields {
  my $self = shift;
  return( @{ $self->{_columnNames} } );
}
#############################################################################
sub _initializeProcessing {
  my $self = shift;

  if ( ! defined( $self->{_currentIncrementalStream} ) ) {
    $self->_openNextFileForIncrementalReading();
  }
}
#############################################################################
sub hasBom {
    my ( $self, $file ) = @_;
    my $hasBom = 0;
    
    open my $filehandle, '<:raw', $file;
    read $filehandle, my $bytes, 3;  # returns number of read bytes
    close( $filehandle );

    if ( $bytes =~  m/^\xEF\xBB\xBF/ ) {
	$hasBom = 1;
    }

    return( $hasBom );
}

#############################################################################
sub _openNextFileForIncrementalReading {
  my $self = shift;

  close( $self->{_currentIncrementalStream} ) if defined( $self->{_currentIncrementalStream} );
  my $csvFile = $self->_getNextFile();

  if ( defined( $csvFile ) ) {
      my $encoding = $self->{encoding};

      # Call the hooks to be called, when a new file is opened (if any)
      $self->_callHooksForNewFile( $csvFile );
      open $self->{_currentIncrementalStream}, "<:encoding(${encoding})", "$csvFile" or confess "Error while reading $csvFile: $!";

      if ( $self->hasBom( $csvFile ) ) {
	  die "Sorry! CSV file '$csvFile' has a BOM. Please remove and try again! Remove e.g. via 'tail +4c $csvFile > $csvFile.noBom'\n";
      }
      
      my $firstRow = $self->{_csvModule}->getline( $self->{_currentIncrementalStream} );   # read away first entry (the headers)

      if ( ! defined( $firstRow ) ) {
	  $self->{_processingFinished} = 1;
      }
      else {
	  $self->{_columnNames} = $firstRow;
      }
  }
  else {
      $self->{_processingFinished} = 1;
      $self->log( 30, "Last input file is finished\n" );
  }
}
#############################################################################
sub _getNextFile {
  my $self = shift;

  return( shift( @{ $self->{inputFiles} } ) );
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
