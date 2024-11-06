package HK::MysqlManager;

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
MySQL manager options: [-h|--help] [--databaseName <databaseName>] [--databaseHostName <hostName>] [--databaseUser <userName>] [--askForPassword]

  Database name must be specified.
  Default database host is localhost.
  Default databaseUser is aloeMySQL.
  If option askForPassword is used, the user will be prompted for a password. Otherwise the password will be read from $ENV{HOME}/.my.cnf
  Default autocommit is true, use parameter userOptions in method connectToDatabase to overwrite.
Sample parameters:
  --databaseName aloe --databaseHostName pc-1234 --databaseUser testUser --askForPassword

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

    my ( $databaseName, $databaseHostName, $databaseUser, $askForPassword );
    my $helpMe;

    # Check command line
    if ( GetOptionsFromArray( $arrayToCheck,
			      "databaseName=s" => \$databaseName,
			      "databaseHostName=s" => \$databaseHostName,
			      "databaseUser=s" => \$databaseUser,
			      "askForPassword" => \$askForPassword,
			      "h" => \$helpMe, "help" => \$helpMe ) ) {
	# okay
	if ( $helpMe ) {
	    # nothing else needed: don't check command line
	}
	else {
	    $self->{databaseName} = $databaseName if defined( $databaseName );
	    $self->{databaseHostName} = defined( $databaseHostName ) ? $databaseHostName : "localhost";
	    $self->{user} = $databaseUser;
	    $self->{askForPasswordFlag} = $askForPassword;

	    # check if module is initialized properly
	    unless( defined( $self->{databaseName} ) ) {
		print STDERR "** Error: No database name specified\n\n";
		$helpMe = 1;
	    }

	    # If no user is specified take the one mentioned in ${HOME}/.my.cnf (if any)
	    my $defaultUser = $self->_guessPasswordlessAccountName();
	    if ( defined( $defaultUser ) ) {
		$self->{user} = $defaultUser unless defined( $self->{user} );
		if ( $self->{user} ne $defaultUser ) {
		    warn "User " . $self->{user} . " is not mentioned in $ENV{HOME}/.my.cnf. Will try access without password, use option --askForPassword if password input is wanted\n";
		}
	    }

	    unless( defined( $self->{user} ) ) {
		print STDERR "** Error: No database user specified and no default user could be found in $ENV{HOME}/.my.cnf\n\n";
		$helpMe = 1;
	    }

	    
	    if ( ! $self->{askForPasswordFlag} and ! -e "$ENV{HOME}/.my.cnf" ) {
		warn "No default configuration file for mysql access ($ENV{HOME}/.my.cnf) was found. Will try access without password, use option --askForPassword if password input is wanted\n";
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

    $self->{dataSource} = "DBI:mysql:database=$databaseName;host=$databaseHostName";

    if ( $self->{askForPasswordFlag} ) {
	# We will try to get the password for user from command line
	$self->{password} = $self->promptForPassword();
    }
    else {
	$self->{password} = undef;
	$self->{dataSource} .= ";mysql_read_default_file=$ENV{HOME}/.my.cnf" if -e "$ENV{HOME}/.my.cnf";
    }

    $self->{defaultConnectOptions} = { RaiseError => 0, PrintError => 0, mysql_enable_utf8 => 1, AutoCommit => 1 };
}
#############################################################################################

sub _guessPasswordlessAccountName {
    my( $self ) = shift;
    my $foundUser = undef;
    my $fileName = "$ENV{HOME}/.my.cnf";
    if ( -e $fileName ) {
	open my $in,  "<:encoding(utf8)", $fileName  or die "Could not open input file '$fileName': $!\n";
	while ( defined( my $input = <$in> ) ) {
	    chomp $input;
	    if ( $input =~ m/^user=\s*(.*)\s*$/ ) {
		$foundUser = $1;
		last;
	    }
	}
	close( $in );
    }
    return( $foundUser );

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
