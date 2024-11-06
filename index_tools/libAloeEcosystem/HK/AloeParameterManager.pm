package HK::AloeParameterManager;

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case :config pass_through :config no_auto_abbrev);
use Data::Dumper;

use File::Basename;

# switch all standard streams to UTF-8
use open qw(:std :utf8);

use Delight::DelightClient;


our $AUTOLOAD;			# it's a package global

# To export only selected functions (or variables), we derive
# from class 'Exporter', so the user can call method 'import()'
# of class 'Exporter'
use Exporter;
our @ISA = ( 'Exporter' );
# which functions to export by default? None. We prefer an OO interface
# so export of functions is probably not needed
our @EXPORT = qw();


#############################################################################
# Constructor of class Delight::AloeManager
sub new {
    my $class = shift;
    my $self  = {};

    bless ($self, $class);

    return $self;
}
#############################################################################

sub initFromCommandlineParameters {
    my $self = shift;
    my $commandLineArguments = shift;

    $self->{verbosity} = 0;
    $self->{baseUrl} = undef;
    $self->{aloeClient} = undef;
    $self->{sessionId} = undef;
    $self->{groupVisibility} = undef;
    $self->{shareToGroups} = undef;

    my( $wasOkay, $helpString ) = $self->checkCommandLine( $commandLineArguments );

    if ( $wasOkay ) {
	# Init default values
	$self->{verbosity} = 0 unless defined( $self->{verbosity} );
	$self->{aloeUserName} = "zeus" unless defined( $self->{aloeUserName} );

	$self->{aloeClient} = Delight::DelightClient->new( baseUrl => $self->{baseUrl}, debugLevel => $self->{verbosity}, mockupMode => $self->{mockupMode} );
	if ( defined( $self->{sessionId} ) ) {
	    $self->{aloeClient}->setSessionId( $self->{sessionId} );
	}
    }

    return( $wasOkay, $helpString );
}
#############################################################################
sub getClient {
    my $self = shift;
    return( $self->{aloeClient} );
}
#############################################################################
sub getShareToGroups {
    my $self = shift;
    return( $self->{shareToGroups} );
}
#############################################################################
sub getEditAccessRightGroupIds {
    my $self = shift;
    return( $self->{editAccessRightGroupIds} );
}
#############################################################################
sub getGroupVisibility {
    my $self = shift;
    return( $self->{groupVisibility} );
}
#############################################################################
sub getAloeUserName {
    my $self = shift;
    return( $self->{aloeUserName} );
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
Aloe options: [-h|--help] [--aloeVerbosity <percentLevel>] [--mockupMode] [--aloeUserName <userName>] [--sessionId <sessionId>] [--shareToGroup <groupId>]* [--groupVisibility <groupId>]
              [--editAccessRightGroupId <groupId>]* [--aloeInstanceUrl <aloeInstanceUrl>]
  Default userName is zeus.
  Debug level should be given in percent (higher or lower values are mapped to 100 or 0 respectively)
  Flag mockupMode will cause a dummy (mockup) module to be used instead of a delight client. All calls will be logged to STDOUT
  If flag sessionId is given, this value will be used as internal session id for all calls
  Please note that options shareToGroup and editAccessRightGroupId are useful only when you add new resources.
  Please note that options shareToGroup and editAccessRightGroupId can be specified more than once.
  Options groupVisibility and shareToGroup are mutually exclusive, because it does not make sense to share resources with group
    visibility to groups

Sample usage:
  $0 --aloeVerbosity 100 --groupVisibility nGDLHIH --aloeInstanceUrl 'http://pc-4164:8094/AloeWebService/delight'
  $0 --aloeInstanceUrl 'http://pc-4164:8094/AloeWebService/delight'
  $0 --aloeInstanceUrl 'http://pc-4164:8094/AloeWebService/delight' --shareToGroup nGDLHIH --shareToGroup nGfderT
  $0 --aloeUserName kurt --editAccessRightGroupId nGDLHIH --aloeInstanceUrl 'http://pc-4164:8094/AloeWebService/delight'
EOTEXT
    return( $errorString );
}
#############################################################################
sub checkCommandLine {
    my ( $self, $arrayToCheck ) = @_;

    my ( $verbosity, $mockupMode, $aloeUserName, $aloeInstanceUrl, $sessionId, $groupVisibility, @shareToGroups, @editAccessRightGroupIds );
    my $helpMe;

    # Check command line
    if ( GetOptionsFromArray( $arrayToCheck,
			      "aloeVerbosity=i" => \$verbosity,
			      "mockupMode" => \$mockupMode,
			      "aloeUserName=s" => \$aloeUserName,
			      "aloeInstanceUrl=s" => \$aloeInstanceUrl,
			      "sessionId=s" => \$sessionId,
			      "shareToGroup=s" => \@shareToGroups,
			      "groupVisibility=s" => \$groupVisibility,
			      "editAccessRightGroupId=s" => \@editAccessRightGroupIds,
			      "h" => \$helpMe, "help" => \$helpMe ) ) {
	# okay
	if ( $helpMe ) {
	    # nothing else needed: don't check command line
	} else {
	    $self->{aloeUserName} = $aloeUserName if defined( $aloeUserName );
	    $self->{verbosity} = $verbosity if defined( $verbosity );
	    $self->{mockupMode} = $mockupMode if defined( $mockupMode );
	    $self->{baseUrl} = $aloeInstanceUrl if defined( $aloeInstanceUrl );
	    $self->{sessionId} = $sessionId if defined( $sessionId );

	    $self->{groupVisibility} = $groupVisibility if defined( $groupVisibility );
	    $self->{shareToGroups} = \@shareToGroups if @shareToGroups > 0;
	    $self->{editAccessRightGroupIds} = \@editAccessRightGroupIds if @editAccessRightGroupIds > 0;

	    if ( defined( $self->{groupVisibility} ) and  @shareToGroups > 0 ) {
		print STDERR "Please specify either a group id for group visibility or a number of group ids to share to\n";
		$helpMe = 1;
	    }

	    # check regular command line parameters
	    if ( ! defined( $self->{baseUrl} ) ) {
		$helpMe = 1;
	    }
	}
    } else {
	$helpMe = 1;
    }

    #print Dumper( $arrayToCheck );


    my $usageString = $self->getUsageString();
    if ( $helpMe ) {
	return( 0, $usageString );
    } else {
	return( 1, $usageString );
    }
}

1;


__END__

=head1 NAME

Aloe::AloeParameterManager - Class to allow for easy usage of AloeWebService.

=head1 SYNOPSIS

  my $aloeManager = Aloe::AloeParameterManager->new();
  my @remainingArguments = $aloeManager->initFromCommandlineParameters( \@ARGV );
  my $aloeClient = $aloeManager->getClient();
  $aloeClient->logInAndAskForPassword();
  $aloeClient->createAnonymousSession();
  # session ids are stored internally and automatically added to all future calls with session id.
  my $metadataBean = $aloeClient->getResourceMetadata( resourceId => '12345' );

=head1 DESCRIPTION

This class allows you to easily handle the commandline parameters used to connect to an AloeWebService. Then you can use this class to get an instance of Delight::DelightClient configured to connect to the specified AloeWebService.

=head1 CONSTRUCTOR

=over 8

=item B<new> ()

Create a new instance of Aloe::AloeParameterManager. Default log level is set to 0.

=back

=head1 METHODS

=over 8

=item B<initFromCommandlineParameters> ( I<arrayReference> )

Initialize the module with the values from the array reference. Usually this will be a reference to @ARGV or a copy. The parameters for Aloe::AloeParameterManager will be used to initialize the module and are removed from the array reference. All other arguments will remain in the array reference as is.

=item B<log> ( I<level>, I<message> )

Log the given message to STDERR if the current log level is greater or equal level. Do nothing otherwise.

=back

=head1 AUTHOR

Heinz Kirchmann <kirchman@dfki.uni-kl.de>
