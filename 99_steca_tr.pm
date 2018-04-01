#
#  99_steca_tr.pm 
#

package main;

use strict;
use warnings;
# use Switch;
use Blocking;
use DevIo;

my $answer;

my %sets = (
  "connect:noArg" => "",
  "disconnect:noArg" => ""
);

sub steca_tr_Initialize() {
  my($hash) = @_;
  Log3("", 5, "steca_tr_Initialize");

  $hash->{ReadFn}   = "steca_tr_Read";
  $hash->{ReadyFn}  = "steca_tr_Ready";
  $hash->{DefFn}    = "steca_tr_Define";
  $hash->{SetFn}    = "steca_tr_Set";
  $hash->{NotifyFn} = "steca_tr_Notify";
  $hash->{UndefFn}  = "steca_tr_Undef";
}


sub steca_tr_Define($$) {
  my($hash, $def) = @_;
  my $name = $hash->{NAME};
  Log3($name, 5, "steca_tr_Define $def");
  
  if($def =~ /^.*?\s+steca_tr\s+(.*)/) {
    $hash->{DeviceName} = $1;
    return DevIo_OpenDev($hash, 0, "steca_tr_DoInit");
  }
  return(undef);
}

sub steca_tr_Set($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;
  my $dev = $hash->{DeviceName};
  
  Log3($name, 5, "steca_tr_Set >$name< >$cmd< >>" . join(",", @args) . "<<");

  # undef($cmd) if($cmd eq "?");

  return "\"set $name\" needs at least one argument" unless(defined($cmd));

  if($cmd eq "disconnect")
  {
      DevIo_CloseDev($hash);
    $hash->{STATE} = "disconnected";
    return("");
  }
  elsif($cmd eq "connect")
  {
    if($hash->{STATE} ne "disconnected") {
      DevIo_CloseDev($hash);
      $hash->{STATE} = "disconnected";
      sleep(5);
    }
    return DevIo_OpenDev($hash, 0, "steca_tr_DoInit");
  }
  return "unknown argument $cmd choose one of " . join(" ", sort keys %sets);
}


sub steca_tr_Notify($$) {
  my($hash, $dev) = @_;
  my $name = $hash->{NAME};
  Log3($name, 5, "steca_tr_Notify $dev");

  RemoveInternalTimer($hash);
}

sub steca_tr_DoInit($) {
  my ($hash) = @_;
  Log3($hash, 5, "steca_tr_DoInit");
  Log3($hash->{NAME}, 5, "steca_tr_DoInit");
  if(not exists($hash->{helper}{DISABLED}) or (exists($hash->{helper}{DISABLED}) and $hash->{helper}{DISABLED} == 0))
  {
    readingsSingleUpdate($hash, "state", "active",0);
    $hash->{helper}{Initialized} = 0;
  }
  else
  {
    readingsSingleUpdate($hash, "state", "disabled",0);
  }

  foreach my $dat (keys %data) {
    Log3($hash->{NAME}, 5, "steca_tr_Data $dat => " . $data{$dat});
  }

  return undef;
}

sub steca_tr_Ready($) {
  my ($hash) = @_;
  my $dev = ${hash}->{DeviceName};
  my $name = ${hash}->{NAME};
  
  Log3($hash->{NAME}, 5, "steca_tr_Ready");
  # delete($readyfnlist{"$name.$dev"});
  DevIo_OpenDev($hash, 1, "steca_tr_DoInit") if($hash->{STATE} eq "disconnected");
  if(defined($hash->{USBDev})) {
    my $po = $hash->{USBDev};
    my ( $BlockingFlags, $InBytes, $OutBytes, $ErrorFlags ) = $po->status;
    return ( $InBytes > 0 );
  }
}

sub steca_tr_Read($) {
  my($hash) = @_;
  my $buf = "";
  my $cnt = 0;
  
  $buf = DevIo_TimeoutRead($hash, 0.1);
  return("") if(!defined($buf) || $buf eq "");
  chomp($buf);
  Log3($hash->{NAME}, 5, "steca_tr_Read >" . $buf . "<");
  return("") if($buf eq "");

  if($buf =~ /^(.*?);(.*?),(.*?),(.*?),(.*?),(.*?),(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);(.*?);/) {

    readingsBeginUpdate($hash);
    readingsBulkUpdateIfChanged($hash, "temptime", $1);
    readingsBulkUpdateIfChanged($hash, "t1", $2);
    readingsBulkUpdateIfChanged($hash, "t2", $3);
    readingsBulkUpdateIfChanged($hash, "t3", $4);
    readingsBulkUpdateIfChanged($hash, "t4", $5);
    readingsBulkUpdateIfChanged($hash, "t5", $6);
    readingsBulkUpdateIfChanged($hash, "t6", $7);
    readingsBulkUpdateIfChanged($hash, "bitmaskinputs", $8);
    readingsBulkUpdateIfChanged($hash, "r1", $9);
    readingsBulkUpdateIfChanged($hash, "r2", $10);
    readingsBulkUpdateIfChanged($hash, "r3", $11);
    readingsBulkUpdateIfChanged($hash, "system", $12);
    readingsBulkUpdateIfChanged($hash, "wmz", $13);
    readingsBulkUpdateIfChanged($hash, "pcurr", $14);
    readingsBulkUpdateIfChanged($hash, "pcomp", $15);
    readingsBulkUpdateIfChanged($hash, "radiation", $16);
    readingsBulkUpdateIfChanged($hash, "countryid", $17);
    readingsBulkUpdateIfChanged($hash, "version", $18);
    readingsBulkUpdateIfChanged($hash, "reglertyp", $19);
    readingsBulkUpdateIfChanged($hash, "tds", $20);
    readingsBulkUpdateIfChanged($hash, "volflowcounter", $21);
    readingsBulkUpdateIfChanged($hash, "ralarm", $22);
    readingsBulkUpdateIfChanged($hash, "reserved", $23);
    readingsEndUpdate($hash, 1);
  }

  return("");
}

sub steca_tr_TimeoutScan($) 
{
  my($hash) = @_;
  RemoveInternalTimer($hash);
  Log3($hash->{NAME}, 5, "steca_tr_TimeoutScan");
  return(undef);
}



sub steca_tr_Undef($$) {
  my ($hash, $arg) = @_;
  Log3($hash->{NAME}, 5, "steca_tr_Undef");

  RemoveInternalTimer($hash);

  if(defined($hash->{helper}{RUNNING_PID}))
  {
    BlockingKill($hash->{helper}{RUNNING_PID});
  }

  DevIo_CloseDev($hash);
  return undef;
}

1;


# Beginn der Commandref

=pod
=item device
=item summary STECA TR 0603 serial logger
=item summary_DE STECA TR 0603 serieller Datenlogger

=begin html
  <a name="steca_tr"></a><h3>steca_tr</h3>
  <ul> 
  <br>
  define logfile:<br>
  define FileLog_steca FileLog ./log/steca-%Y-%m.log steca:.*
  </ul>
=end html

=begin html_DE
  <a name="steca_tr"></a><h3>steca_tr</h3>
  <ul> 
  <br>
  Logdatei anlegen:<br>
  define FileLog_steca FileLog ./log/steca-%Y-%m.log steca:.*
  </ul>
=end html

# Ende der Commandref
=cut

