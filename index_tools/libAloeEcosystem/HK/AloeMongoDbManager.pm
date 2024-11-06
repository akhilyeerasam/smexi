package HK::AloeMongoDbManager;

use strict;
use warnings;
use Data::Dumper;

use MongoDB;

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
# Constructor of class Aloe::AloeMongoDbManager
#  Parameters: serviceDescription (<server>:<port>) and databaseName
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

  my $mongoServiceDescription = shift;
  if ( $mongoServiceDescription =~ m/^\s*(.*):(\d+)\s*$/ ) {
    $self->{server} = $1;
    $self->{port} = $2;
    $self->{mongoClient} = MongoDB::MongoClient->new( host => $self->{server}, port => $self->{port} );
  }
  else {
    die "Illegal service description: should be <server>:<port> but was ''\n";
  }
  $self->{databaseName} = shift;
  $self->{database} = $self->{mongoClient}->get_database( $self->{databaseName} );
  $self->{collectionName} = shift;

}

#############################################################################
sub isAlreadyStored {
  my( $self, $item ) = @_;
  my $isStored = 0;

  my $videoId = $item->{id}->{videoId};

  my $collection = $self->{database}->get_collection( $self->{collectionName} );

  # To filter using an exact structure, build corresponding instance in perl and use as filter. This will match
  # only, if the structure is exactly like the filter:
  #    my $x = { "id" => { "videoId" => $videoId } };
  #    my $cursor = $collection->query( $x );
  # To filter using a value not in first level use dot notation. 'id.videoId' will find all documents with subdocument
  # 'id' containing a field 'videoId' with the corresponding value
  my $cursor = $collection->query( { 'id.videoId' => $videoId } );
  if ( $cursor->next ) {
    $isStored = 1;
  }
  #die ref( $item ) . "\n";

  return( $isStored );
}

#############################################################################

sub storeInMongoDb {
  my( $self, $toStore ) = @_;

  my $collection = $self->{database}->get_collection( $self->{collectionName} );
  if ( ref( $toStore ) eq "HASH" ) {
    $collection->insert( $toStore );
  }
  else {
    die "MongoDb can store only hashes\n";
  }
}

#############################################################################

# Draft!!
sub draft_storeInMongoDb {
  my( $toStore ) = @_;

  my $client = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );  # 27017 is mongoDB's default
  my $database = $client->get_database( 'aloetest' );
  my $collection = $database->get_collection( 'collection1' );
  my $y = { "videoId" => "huhu" };
  my $x = { "id" => $y };
  my $cursor = $collection->query( $x );


  #my $query = $collection->query({ a => "b" })->sort({ age => 1 });
  #my $cursor = $collection->query( { "id" => {videoId} => {meineid} } );

  while ( my $nextElement = $cursor->next ) {
    print STDERR Dumper( $nextElement), "\n";
  }

  #my $data = $collection->find_one({ _id => $id });
  #my @objects = $cursor->all;
}
1;
