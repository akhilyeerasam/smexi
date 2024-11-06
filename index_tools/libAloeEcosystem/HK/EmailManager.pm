package HK::EmailManager;

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case :config pass_through :config no_auto_abbrev);

use Term::ReadKey;
use MIME::Lite;

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

# Constructor of class HK::EmailManager
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
EmailManager manager options: [-h|--help] [--smtpServer <smtpServer>] [--askForPassword]

Sample parameters:
  --smtpServer serv-4100.kl.dfki.de

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

    my ( $smtpServer, $askForPassword );
    my $helpMe;

    # Check command line
    if ( GetOptionsFromArray( $arrayToCheck,
			      "smtpServer=s" => \$smtpServer,
			      "askForPassword" => \$askForPassword,
			      "h" => \$helpMe, "help" => \$helpMe ) ) {
	# okay
	if ( $helpMe ) {
	    # nothing else needed: don't check command line
	}
	else {
	    $self->{smtpServer} = $smtpServer if defined( $smtpServer );
	    $self->{askForPasswordFlag} = $askForPassword;
	}
    }
    else {
	$helpMe = 1;
    }

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

}
#############################################################################################
sub _sendMessage {
    my ( $self, $message ) = @_;
    my $okayOrNot;

    if ( defined( $self->{smtpServer} ) ) {
	$okayOrNot = $message->send( 'smtp' => $self->{smtpServer} );
	#$message->send( 'smtp' => $self->{smtpServer}, Debug=>1 );
    }
    else {
	$okayOrNot = $message->send; # send via default
    }

    unless( $okayOrNot ) {
	warn "Could not send mail ". $message->as_string, "\n";
    }

    return( $okayOrNot );
}
#############################################################################################

# Parameters should be something like
# ( From =>'me@myhost.com', To =>'you@yourhost.com', Cc =>'some@other.com, some@more.com',
#   Subject  =>'Helloooooo, nurse!', Data =>"How's it goin', eh?" )
sub sendMail {
    my ( $self, %parameters ) = @_;
    my $message = MIME::Lite->new( %parameters );

    return( $self->_sendMessage( $message ) );
}
#############################################################################################
# Attachment should be something like
#   ( Type => 'image/gif', Id   => 'myimage.gif', Path => '/path/to/somefile.gif' )
sub sendMailWithAttachment {
    my ( $self, $attachmentData, %parameters ) = @_;
    my $message = MIME::Lite->new( %parameters );
    $message->attach( %$attachmentData );

    return( $self->_sendMessage( $message ) );
}
#############################################################################################

sub sendHtmlMail {
    my ( $self, $htmlText, %parameters ) = @_;

    my $message = MIME::Lite->new( %parameters, Type => 'multipart/related' );

    #$message->attr( "content-type"         => "text/html");
    $message->attr( "content-type.charset" => "utf-8");

    $message->attach( Type => 'text/html', Data => $htmlText );

    return( $self->_sendMessage( $message ) );
}
#############################################################################################
# Get settings for access to smtp server
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
# Get settings for access to smtp server
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
