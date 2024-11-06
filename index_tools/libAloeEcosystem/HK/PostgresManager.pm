package HK::PostgresManager;

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case :config pass_through :config no_auto_abbrev);

use Term::ReadKey;
use DBI;

# To export only selected functions (or variables), we derive
# from class 'Exporter', so the user can call method 'import()'
# of class 'Exporter'
use Exporter;
our @ISA = ( 'Exporter' );
# which functions to export by default?
our @EXPORT = qw();
# which functions to export byuser request?
our @EXPORT_OK = qw();


#############################################################################################

# Constructor of class Nexus::MysqlManager
sub new {
    my $class = shift;
    my $self  = {};

    bless ($self, $class);

    return $self;
}

#############################################################################
sub getUsageString {
    my ( $self ) = @_;
    my $errorString = <<"EOTEXT";
PostgresManager options: [-h|--help] [--databaseName <databaseName>] [--databaseHostName <hostName>] [--databaseUser <userName>]

  Database name must be specified.
  Default database host is localhost
  The user will be prompted for a password
  Default autocommit is true, use parameter userOptions in method connectToDatabase to overwrite.
Sample parameters:
  --databaseName aloe --databaseHostName pc-1234 --databaseUser testUser

EOTEXT
    return( $errorString );
}
#############################################################################

sub initFromCommandlineParameters {
    my $self = shift;
    my $commandLineArguments = shift;

    $self->{dataSource} = undef;
    $self->{password} = undef;

    my $wasOkay = $self->checkCommandLine( $commandLineArguments );

    if ( $wasOkay ) {
	# Init default values (if any)
	$self->_init();
    }

    return( $wasOkay );
}

#############################################################################
sub checkCommandLine {
    my ( $self, $arrayToCheck ) = @_;

    my ( $databaseName, $databaseHostName, $databaseUser );
    my $helpMe;

    # Check command line
    if ( GetOptionsFromArray( $arrayToCheck,
			      "databaseName=s" => \$databaseName,
			      "databaseHostName=s" => \$databaseHostName,
			      "databaseUser=s" => \$databaseUser,
			      "h" => \$helpMe, "help" => \$helpMe ) ) {
	# okay
	if ( $helpMe ) {
	    # nothing else needed: don't check command line
	}
	else {
	    $self->{databaseName} = $databaseName if defined( $databaseName );
	    $self->{databaseHostName} = defined( $databaseHostName ) ? $databaseHostName : "localhost";
	    $self->{user} = $databaseUser;

	    # check if module is initialized properly
	    unless( defined( $self->{databaseName} ) ) {
		print STDERR "** Error: No database name specified\n\n";
		$helpMe = 1;
	    }

	    unless( defined( $self->{user} ) ) {
		print STDERR "** Error: No database user specified\n\n";
		$helpMe = 1;
	    }
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
#############################################################################################

sub _init {
    my $self = shift;

    my $databaseName = $self->{databaseName};
    my $databaseHostName = $self->{databaseHostName};

    $self->{dataSource} = "DBI:Pg:database=$databaseName;host=$databaseHostName";

    # We will try to get the password for user from command line
    $self->{password} = $self->promptForPassword();

    #$self->{defaultConnectOptions} = { RaiseError => 0, PrintError => 0, mysql_enable_utf8 => 1, AutoCommit => 1 };
    $self->{defaultConnectOptions} = { RaiseError => 1, PrintError => 1, AutoCommit => 1 };
}
#############################################################################################
sub getDatabaseHandler {
    my( $self ) = shift;
    return( $self->{databaseHandler} );
}

#############################################################################################
sub disconnect {
    my( $self ) = shift;
    $self->{databaseHandler}->disconnect();
}

#############################################################################################
sub commit {
    my( $self ) = shift;
    $self->{databaseHandler}->commit();
}

#############################################################################################
sub rollback {
    my( $self ) = shift;
    $self->{databaseHandler}->rollback();
}
#############################################################################################
sub prepare {
    my( $self ) = shift;

    return( $self->{databaseHandler}->prepare( @_ ) );
}

#############################################################################################
# userOptions may contain valid extra options for the connection, like
#   AutoCommit => 0
sub connectToDatabase {
    my( $self, $userOptions ) = @_;

    my %additionalOptions = %{ $self->{defaultConnectOptions} };

    if ( defined( $userOptions ) ) {
	while ( my( $key, $value ) = each %$userOptions ) {
	    $additionalOptions{$key} = $value;
	}
    }

    my $driverHandle = DBI->install_driver("mysql") || die "Could not install mysql driver\n";
    $self->{databaseHandler} = DBI->connect( $self->{dataSource}, $self->{user}, $self->{password}, \%additionalOptions ) ||
	die "Could not connect to datasource '" . $self->{dataSource} . "': $!\n";
    # If the default mysql configuration does not contain we have to do it explicitly
    $self->{databaseHandler}->do( "set NAMES 'utf8'" );
}

#############################################################################################
# Get settings for access to svn repository
sub promptForPassword {
    my $self = shift;
    print STDERR "Password: ";
    ReadMode 'noecho';
    my $password = ReadLine( 0 );
    ReadMode 'normal';
    print STDERR "\n";
    chomp($password);

    return( $password );
}
#############################################################################################
# Get settings for access to svn repository
sub promptForUserAndPassword {
    my $self = shift;
    print STDERR "Username (default:aloeMySQL): ";
    my $username = ReadLine( 0 );
    chomp($username);
    if ( ! defined( $username ) or $username =~ m/^\s*$/ ) {
	$username = "aloeMySQL";
    }

    print STDERR "Password: ";
    ReadMode 'noecho';
    my $password = ReadLine( 0 );
    ReadMode 'normal';
    print STDERR "\n";
    chomp($password);

    return( $username, $password );
}


1;
