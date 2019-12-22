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
    'fake-today=s',
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

if ($opts{"fake-today"}) {
    my @ymd = split /[\/\-]/, $opts{"fake-today"};
    if (@ymd == 3) {
        $today = DateTime->new(
            year      => $ymd[0],
            month     => $ymd[1],
            day       => $ymd[2],
            hour      => '0',
            minute    => '0',
            second    => '0',
            time_zone => 'Asia/Taipei',
        );
    } else {
        die "Unknown date format in `--fake-today`. Try: 2020/01/11"
    }
}

my $diff_seconds = $vote_date->epoch - $today->epoch();
my $diff_days = int $diff_seconds/86400;

exit(0) if $diff_days < -1;

my $hashtags = "\n\n#TaiwanElection #TaiwanVotes #Taiwan2020 #台灣選舉 #台灣投票";
my %specials = (
    19 => '#總統要投幾號呢？🤔',
    18 => '#立委要投誰呢？🤔',
    17 => '#政黨票投給哪一黨好呢？🤔',
    5  => '#機票買了沒？✈',
    4  => '#車票買了沒？🚄',
);
@specials{16,15,14,13,12,11,10,9,8,7,6} = (@specials{19,18,17})x4;

my $msg;
if ($diff_days > 1) {
    my $sp = $specials{$diff_days} // '#記得去投票';
    $diff_days =~ tr/0123456789/０１２３４５６７８９/;
    $msg = sprintf('離下次投票 %s ... 還有 %s 天。', $vote_date->ymd("/"), $diff_days);
    $msg .= "\n\n\n$sp" . $hashtags;
} elsif ($diff_days == 1) {
    $msg = '投票日... 就是明天呢。' . "\n\n\n#記得去投票" . $hashtags;
} elsif ($diff_days == 0) {
    $msg = '投票日... 不就是今天嗎。' . "\n\n\n#你投票了嗎" . $hashtags;
} elsif ($diff_days == -1) {
    $msg = '投票日倒數完畢... 總算可以下班了。';
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
    say "\n----\nNot Tweeting";
}
