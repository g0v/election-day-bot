use v5.32;
use warnings;
use feature 'signatures';
use utf8;

use Twitter::API;
use YAML;
use DateTime;
use Encode ('encode_utf8');
use Getopt::Long ('GetOptionsFromArray');
use List::MoreUtils ('part');

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
        ["2021/10/23", "第10屆立法委員臺中市第2選舉區陳柏惟罷免案", "https://www.cec.gov.tw/central/cms/110news/35453"],
        ["2021/12/18", "全國性公民投票", "https://www.cec.gov.tw/central/cms/110news/35412"],
        ["2022/01/09", "立法委員臺中市第2選舉區缺額補選", "https://www.cec.gov.tw/central/cms/110news/35853"],
        ["2022/01/09", "第10屆立法委員林昶佐罷免案", "https://web.cec.gov.tw/central/cms/110news/36048"],
        ["2022/11/26", "地方公職人員選舉", "https://www.cec.gov.tw/central/cms/111news/36291"],
        ["2022/11/26", "111年憲法修正案之複決案", "https://www.cec.gov.tw/central/cms/111news/36606"],
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

sub titles ($votes) {
    my @titles = map { "#". $_->{"title"} } @$votes;
    if (@titles == 1) {
        return $titles[0];
    } else {
        return "- " . join("\n- ", @titles);
    }
}

sub build_countdown_message ($today, $votes) {
    my @votes = map {
        my $date = DateTime_from_ymd( $_->[0] );
        my $diff_days = int ($date->epoch - $today->epoch())/86400;

        +{
            "date" => $date->ymd("/"),
            "title" => $_->[1],
            "url" => $_->[2],
            "diff_days" => $diff_days,
        }
    } @$votes;

    my ($past_votes, $yesterday_votes, $today_votes, $tomorrow_votes, $upcoming_votes) = part {
        my $diff = ($_->{"diff_days"} + 2);
        $diff <= 0 ? 0 : $diff >= 4 ? 4 : $diff;
    } @votes;

    my $msg = "";
    my $hashtags = "#台灣投票\n#TaiwanVotes";

    if ($today_votes) {
        $msg = "投票日... 不就是今天嗎。\n\n" . titles($today_votes) . "\n\n#你投票了嗎\n" . $hashtags;
    }
    elsif ($tomorrow_votes) {
        $msg = "投票日... 就是明天呢。\n\n" . titles($tomorrow_votes) . "\n\n#記得去投票\n" . $hashtags;
    }
    elsif ($upcoming_votes) {
        $msg = join(
            "\n\n",  map {
                "離 #" . $_->{"title"} . " 投票日 " . $_->{"date"} . " 還有 " . $_->{"diff_days"} . " 天。"
            } @$upcoming_votes
        ) . "\n\n" . $hashtags;
    }
    elsif ($yesterday_votes) {
        $msg = '投票日倒數完畢 ! 總算可以放假了。';
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
