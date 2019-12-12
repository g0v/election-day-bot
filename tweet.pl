use v5.14;
use utf8;
use Net::Twitter;
use YAML;
use Encode qw(encode_utf8);
use Getopt::Long qw(GetOptions);
use DateTime;

my %opts;
GetOptions(
    \%opts,
    'c=s',
    'y|yes'
) or die("Error in arguments, but I'm not telling you what it is.");

($opts{c} && -f $opts{c}) or die "Your config does not exist.";
my $config = YAML::LoadFile( $opts{c} );

# 2020/01/11: https://www.cec.gov.tw/central/cms/108news/30126
my $vote_date = DateTime->new(
    year      => '2020',
    month     => '1',
    day       => '11',
    hour      => '0',
    minute    => '0',
    second    => '0',
    time_zone => 'Asia/Taipei',
);

my $today = DateTime->now( time_zone => 'Asia/Taipei' )->truncate( to => 'day' );
my $diff_seconds = $vote_date->epoch - $today->epoch();
my $diff_days = int $diff_seconds/86400;

my $msg = sprintf(
    '離下次投票 %s ...還有 %d 天。' .
    "\n\n\n" .
    '#記得去投票' .
    "\n\n" .
    '#TaiwanElection #TaiwanVotes #Taiwan2020 #台灣選舉 #台灣投票' ,
    $vote_date->ymd("/"), $diff_days
);

if ($diff_days == 0) {
    $msg = '投票日.... 不就是今天嗎。';
} elsif ($diff_days == 1) {
    $msg = '投票日.... 是明天呢。';
} elsif ( $diff_days < 0 ) {
    $msg = '離下次投票，倒底還有幾天呢...'
}

say encode_utf8($msg);

if ($opts{y}) {
    say "Tweet for real";
    my $twitter = Net::Twitter->new(
        ssl => 1,
        traits => [ 'API::RESTv1_1' ],
        consumer_key        => $config->{consumer_key},
        consumer_secret     => $config->{consumer_secret},
        access_token        => $config->{access_token},
        access_token_secret => $config->{access_token_secret},
    );

    $twitter->update($msg);
}
else {
    say "Not Tweeting";
}
