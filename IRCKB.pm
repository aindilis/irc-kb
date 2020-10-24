package IRCKB;

use IRCKB::ParseLogs;

use BOSS::Config;
# use MyFRDCSA;

use Data::Dumper;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / Config /

  ];

sub init {
  my ($self,%args) = @_;
  $specification = "
	-u [<host> <port>]	Run as a UniLang agent

	-p			Parse logs

	-a			Parse all logs
	-n			Parse notable logs

	-o <operation>		Operation (extract-commitments, all-uses)

	-l			Limit input

	-f <filter>		Log name filter

	-w			Require user input before exiting
";
  # $UNIVERSAL::systemdir = ConcatDir(Dir("internal codebases"),"irckb");
  $self->Config(BOSS::Config->new
		(Spec => $specification,
		 ConfFile => ""));
  my $conf = $self->Config->CLIConfig;
  $UNIVERSAL::agent->DoNotDaemonize(1);
  if (exists $conf->{'-u'}) {
    $UNIVERSAL::agent->Register
      (Host => defined $conf->{-u}->{'<host>'} ?
       $conf->{-u}->{'<host>'} : "localhost",
       Port => defined $conf->{-u}->{'<port>'} ?
       $conf->{-u}->{'<port>'} : "9000");
  }
}

sub Execute {
  my ($self,%args) = @_;
  my $conf = $self->Config->CLIConfig;
  if (exists $conf->{'-p'}) {
    my $parselogs = IRCKB::ParseLogs->new();
    my $res1;
    if ($conf->{'-a'}) {
      $res1 = $parselogs->ParseLogs
	(
	 Limit => $conf->{'-l'},
	 Operation => $conf->{'-o'} || 'none',
	 Filter => $conf->{'-f'},
	);
    } elsif ($conf->{'-n'}) {
      $res1 = $parselogs->ParseLogs
	(
	 LogDir => '<REDACTED>',
	 Limit => $conf->{'-l'},
	 Operation => $conf->{'-o'} || 'none',
	 Filter => $conf->{'-f'},
	);
    }
    print Dumper({Res1 => $res1});
  }
  if (exists $conf->{'-u'}) {
    # enter in to a listening loop
    while (1) {
      $UNIVERSAL::agent->Listen(TimeOut => 10);
    }
  }
  if (exists $conf->{'-w'}) {
    Message(Message => "Press any key to quit...");
    my $t = <STDIN>;
  }
}

sub ProcessMessage {
  my ($self,%args) = @_;
  my $m = $args{Message};
  my $it = $m->Contents;
  my $data = $m->Data;
  if ($it) {
    if ($it =~ /^echo\s*(.*)/) {
      $UNIVERSAL::agent->SendContents
	(Contents => $1,
	 Receiver => $m->{Sender});
    } elsif ($it =~ /^(quit|exit)$/i) {
      $UNIVERSAL::agent->Deregister;
      exit(0);
    }
  } elsif (exists $data->{Message}) {
    print Dumper($data);
  }
}

1;
