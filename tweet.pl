use v5.14;
use warnings;
use feature 'signatures';
use utf8;

use Twitter::API;
use YAML;
use DateTime;
use Encode ('encode_utf8');
use Getopt::Long ('GetOptionsFromArray');

sub main {
    my @args = @_;

    my %opts;
    GetOptionsFromArray(
        \@args,
        \%opts,
        'fake-today=s',
        'github-secret',
        'c=s',
        'y|yes'
    ) or die("Error in arguments, but I'm not telling you what it is.");

    my $today = $opts{"fake-today"} ? DateTime_from_ymd( $opts{"fake-today"} ) : DateTime->now( time_zone => 'Asia/Taipei' )->truncate( to => 'day' );

    # Sorted by date.
    my @votes = (
        # Date, Title, URL
        ["2021/02/06", "高雄市議員黃捷罷免案", "https://www.cec.gov.tw/central/cms/110news/34965"],

        # placeholder -- on this day, CEC made announcement of some changes of dates. See
        # 1. https://www.cec.gov.tw/central/cms/110news/35416
        # 2. https://www.cec.gov.tw/central/cms/110news/35412
        ["2021/07/02", undef, undef],

        ["2021/08/28", "第10屆立法委員（臺中市第2選舉區）陳柏惟罷免案", "https://www.cec.gov.tw/central/cms/110news/34920"],
        ["2021/12/18", "全國性公民投票", "https://www.cec.gov.tw/central/cms/110news/35412"],
    );

    my $msg = build_countdown_message( $today, \@votes );
    maybe_tweet_update(\%opts, $msg);

    return 0;
}

exit(main(@ARGV));

sub DateTime_from_ymd ($s) {
    my @ymd = split /[\/\-]/, $s;

    if (@ymd != 3) {
        die "Unknown date format in '$s'. Try something like: 2020/01/11";
    }

    return DateTime->new(
        year      => $ymd[0],
        month     => $ymd[1],
        day       => $ymd[2],
        hour      => '0',
        minute    => '0',
        second    => '0',
        time_zone => 'Asia/Taipei',
    );
}

sub build_countdown_message ($today, $votes) {
    my ($title, $url, $diff_days, $vote_date, $just_finished);
    for my $vote (@$votes) {
        $vote_date = DateTime_from_ymd( $vote->[0] );
        $title = $vote->[1];
        $url = $vote->[2];

        $diff_days = int ($vote_date->epoch - $today->epoch())/86400;

        last if $diff_days >= 0;

        if ($diff_days == -1) {
            $just_finished = 1;
        }
    }

    my $msg = "";
    my $hashtags = "";
    $hashtags = "\#${title}\n\n#台灣投票\n#TaiwanVotes" if $title;

    if ($diff_days > 1) {
        if ($just_finished) {
            $msg = "接著開始倒數下次投票日。將於 " . $vote_date->ymd("/") . " 舉辦的：\n\n    $title\n\n詳見： $url";
        } else {
            $msg = "離下次投票 " . $vote_date->ymd("/") . " ... 還有 $diff_days 天。\n\n" . $hashtags;
        }
    } elsif ($diff_days == 1) {
        if ($title) {
            $msg = '投票日... 就是明天呢。' . "\n\n\n#記得去投票\n" . $hashtags;
        }
    } elsif ($diff_days == 0) {
        if ($title) {
            $msg = '投票日... 不就是今天嗎。' . "\n\n\n#你投票了嗎\n" . $hashtags;
        }
    } elsif ($diff_days == -1) {
        if ($title) {
            $msg = '投票日倒數完畢 ! 總算可以放假了。';
        }
    }

    return $msg;
}

sub maybe_tweet_update ($opts, $msg) {
    unless ($msg) {
        say "# Message is empty.";
        return;
    }

    my $config;

    if ($opts->{c} && -f $opts->{c}) {
        say "[INFO] Loading config from $opts->{c}";
        $config = YAML::LoadFile( $opts->{c} );
    } elsif ($opts->{'github-secret'} && $ENV{'TWITTER_TOKENS'}) {
        say "[INFO] Loading config from env";
        $config = YAML::Load($ENV{'TWITTER_TOKENS'});
    } else {
        say "[INFO] No config.";
    }

    say "# Message";
    say "-------8<---------";
    say encode_utf8($msg);
    say "------->8---------";

    if ($opts->{y} && $config) {
        say "#=> Tweet for real";
        my $twitter = Twitter::API->new_with_traits(
            traits => "Enchilada",
            consumer_key        => $config->{consumer_key},
            consumer_secret     => $config->{consumer_secret},
            access_token        => $config->{access_token},
            access_token_secret => $config->{access_token_secret},
        );
        my $r = $twitter->update($msg);
        say "https://twitter.com/" . $r->{"user"}{"screen_name"} . "/status/" . $r->{id_str};
    } else {
        say "#=> Not tweeting";
    }
}
