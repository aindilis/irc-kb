package IRCKB::ParseLogs;

use PerlLib::SwissArmyKnife;

use HTML::Strip;
use JSON;
use Lingua::EN::Sentence qw(get_sentences);
use Lingua::EN::Tagger;
use Try::Tiny;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / Attribute Verbose AllResults RTEData HTMLStrip MyJSON  /

  ];

sub init {
  my ($self,%args) = @_;
  $self->Verbose(1);
  $self->AllResults({});
  $self->HTMLStrip(HTML::Strip->new());
  $self->MyJSON(JSON->new()->canonical([1]));
}

sub ParseLogs {
  my ($self,%args) = @_;
  my $logdir = $args{LogDir}; || $ENV{HOME}.'/.erc/logs';

  if ($args{Operation} eq 'extract-commitments') {
    $self->RTEData([]);
  }

  my $i = 0;
  foreach my $file (split /\n/, `ls $logdir`) {
    if ($args{Filter}) {
      next unless $file =~ /$args{Filter}/;
    }
    print STDERR "<$file>\n";
    $self->ProcessLog
      (
       File => ConcatDir($logdir,$file),
       Operation => $args{Operation},
      );
    ++$i;
    if ($args{Limit}) {
      if ($i > 10) {
	last;
      }
    }
  }

  print Dumper({AllResults => $self->AllResults});
  # print Dumper($systems);

  if ($args{Operation} eq 'extract-commitments') {
    WriteFile
      (
       File => '/var/lib/myfrdcsa/codebases/minor/irc-kb/data/output/commitments/commitments-'.DateTimeStamp().'.jsonl',
       Contents => join("\n",@{$self->RTEData}),
      );
  }
}

sub ProcessLog {
  my ($self,%args) = @_;
  my $title = $args{File};
  $title =~ s/[^a-zA-Z0-9]/_/sg;
  my $c = read_file($args{File});
  my @lines;
  my $entries = {};
  my $entry = {};
  my $i = 1;
  foreach my $line (split /\n/, $c) {
    if ($line =~ /^(\d\d(\d\d)?[:-]\d\d[:-]\d\d( \d\d:\d\d:\d\d)?)( \*\*\*)?\s+?(.*?)$/) {
      # wrap up the previous line if exists
      if (scalar @lines) {
	my @linescopy = @lines;
	$entry->{Lines} = \@linescopy;
	my $entrycopy = {};
	foreach my $key (keys %$entry) {
	  $entrycopy->{$key} = $entry->{$key};
	}
	$entries->{$i++} = $entrycopy;
	print $i."\n" if $self->Verbose > 3;
	@lines = ();
      }
      my $time = $1;
      my $sender = "unknown";
      my $receiver = "unknown";
      my $restofline = $5;
      if ($restofline =~ /^<([^>]+)>( (.+?))?$/) {
	$sender = $1;
	$restofline = $3 || '';
	# print "<<<$restofline>>>\n";
	if ($restofline =~ /^(\w+)[:,]\b\s*(.*?)$/) {
	  $receiver = $1;
	  $restofline = $2;
	}
      }
      print 'R: '.$restofline."\n" if $self->Verbose > 3;
      push @lines, $restofline;
      $entry->{Time} = $time;
      $entry->{Sender} = $sender;
      $entry->{Receiver} = $receiver;
    } else {
      $line =~ s/^\s+//sg;
      print 'L: '.$line."\n" if $self->Verbose > 3;
      push @lines, $line;
    }
  }
  my @linescopy = @lines;
  $entry->{Lines} = \@linescopy;
  my $entrycopy = {};
  foreach my $key (keys %$entry) {
    $entrycopy->{$key} = $entry->{$key};
  }
  $entries->{$i++} = $entrycopy;
  @lines = ();

  print Dumper($entries) if $self->Verbose > 3;

  print Dumper($entries) if $self->Verbose > 3;
  my $systems = {};
  my @rtedata;
  foreach my $key (sort {$a <=> $b} keys %$entries) {
    my $entry = $entries->{$key};
    my $time = $entry->{Time};
    my $sender = $entry->{Sender};
    my $receiver = $entry->{Receiver};
    my $lines = $entry->{Lines};
    next unless $lines;
    my $line = join(' ',map {$_ || ' '} @$lines);
    $line =~ s/\.$//sg;
    next unless $sender and $receiver and $time and $line;
    my $jlines = join(" ",map {$_ || ' '} @$lines);
    # print $jlines."\n";
    if ($args{Operation} eq 'all-uses') {
      if ($jlines =~ /I use (\S+)/s) {
	push @{$systems->{$sender}{'I use'}}, $jlines;
      }
      if ($jlines =~ /I am using (\S+)/s) {
	push @{$systems->{$sender}{'I am using'}}, $jlines;
      }
      if ($jlines =~ /I like (\S+)/s) {
	push @{$systems->{$sender}{'I like'}}, $jlines;
      }
    } elsif ($args{Operation} eq 'extract-commitments') {
      my $sentences = get_sentences($jlines);
      foreach my $sentence (@$sentences) {
	$sentence =~ s/<param>.*?<\/param>/ /sg;
	my $clean_text = $self->HTMLStrip->parse( $sentence );
	$clean_text =~ s/^\s+//s;
	$clean_text =~ s/\s+$//s;
	$clean_text =~ s/^\S+ >\s+//s;
	my $rteentry =
	  {
	   premise => $clean_text,
	   hypothesis => 'I am going to do something',
	  };
	push @{$self->RTEData}, $self->MyJSON->encode($rteentry);
      }
    }
  }
  if ($args{Operation} eq 'all-uses') {
    $self->ExtractNamedEntities(Systems => $systems);
  }
}

sub ExtractNamedEntities {
  my ($self,%args) = @_;
  my $p = new Lingua::EN::Tagger;
  my $newresults = {};
  foreach my $user (keys %{$args{Systems}}) {
    foreach my $keyword (keys %{$args{Systems}->{$user}}) {
      my $results = {};
      foreach my $sentence (@{$args{Systems}->{$user}{$keyword}}) {
	my $tagged_text = $p->add_tags($sentence);
	# print STDERR "$tagged_text\n";
	my %word_list = $p->get_max_noun_phrases($tagged_text);
	# print STDERR Dumper(\%word_list);
	my $processed = $sentence;
	$processed =~ s/.*?$keyword//sg;
	my $score = {};
	foreach my $word (keys %word_list) {
	  my $qword = shell_quote($word);
	  $qword =~ s/\\/\\\\/sg;
	  $qword =~ s/\(/\\\(/sg;
	  $qword =~ s/\)/\\\)/sg;
	  $qword =~ s/^'//;
	  $qword =~ s/'$//;
	  try {
	    if ($processed =~ /^(.*?)$qword(.*)$/) {
	      $score->{$word} = length($1);
	    }
	  } catch {
	    warn "caught error: $_";
	  };
	}
	my $bestmatch = [sort {$score->{$a} <=> $score->{$b}} keys %$score]->[0];
	if ($bestmatch) {
	  $results->{$sentence} = [$bestmatch];
	}
      }
      foreach my $key (keys %$results) {
	$newresults->{$user}{$keyword}{$key} = $results->{$key};
	$self->AllResults->{$user}{$keyword}{$key} = $results->{$key};
      }
      $args{Systems}->{$user}{$keyword} = [];
    }
  }
  print STDERR Dumper($newresults);
}

1;
