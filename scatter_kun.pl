#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use 5.010;

use UnazuSan;
use Redis;
use Text::Xslate;
use Data::Section::Simple;

my $unazu_san = UnazuSan->new(
    nickname      => 'scatter_kun',
    host          => 'irc.freenode.net',
    password      => '',
    join_channels => [qw/kenjiskywalker/],
    enable_ssl    => 0,
);

my $r = Redis->new(
    server => 'localhost:6379',
);

my $url      = "http://www.kenjiskywalker.org/scatter/";
my $filepath = "/home/skywalker/www/scatter/";


$unazu_san->on_message(
    qr/^$unazu_san->{nickname}:\s+([\w\-.]+)\s+([\w\-.]+)\s+([\d\-.]+)\s+([\d\-.]+)/ => sub {
        my ($receive, $name, $state, $concurrency, $score) = @_;

        if ($state eq "ADD") {
            warn "ADD";
            my $msg = add_scatter($name, $concurrency, $score);
            warn $msg;

            $receive->reply("ADD"." ".$name." ".$concurrency." ".$score);
            $receive->reply("$msg");
        }
        elsif ($state eq "DEL") {
            warn "DEL";
            my $msg = delete_scatter($name, $concurrency, $score);
            warn $msg;

            $receive->reply("DEL "." ".$name." ".$concurrency." ".$score);
            $receive->reply("$msg");
        }
        else {
            warn "ELSE";
            $receive = shift;
            $receive->reply('hoge[graph_name] state[ADD|DEL|ALLDEL] n[concurrency] m[score]');
        }
    },
    qr/^$unazu_san->{nickname}:\s+([\w\-.]+)\s+([\w\-.]+)/ => sub {
        my ($receive, $name, $state, $concurrency, $score) = @_;
        if ($state eq "ALLDEL") {
            warn "ALLDEL";
            my $msg = all_delete_scatter($name);
            warn $msg;
            $receive->reply($msg);
        }
        else {
            warn "ELSE";
            $receive = shift;
            $receive->reply('hoge[graph_name] state[ADD|DEL|ALLDEL] n[concurrency] m[score]');
        }
    },
    qr/^$unazu_san->{nickname}:/ => sub {
        my ($receive, $match) = @_;
        $receive = shift;
        $receive->reply('hoge[graph_name] state[ADD|DEL|ALLDEL] n[concurrency] m[score]');
    },
);

$unazu_san->run;

sub createe_scatter_view {
    my ($name, $concurrency, $score) = @_;

    my $vpath = Data::Section::Simple->new()->get_data_section();
    my $tx    = Text::Xslate->new(path => [$vpath]);

    my @concurrency_list = $r->hkeys($name);

    my %name_concurrency_scores;
    for my $key (@concurrency_list){
        my $score = $r->hget($name, $key);
        $name_concurrency_scores{"$key"} = $score;
    }

    my $html = $tx->render("template.tx",
        {
            name => $name,
            data => \%name_concurrency_scores,
        }
    );

    my $file = $filepath . $name.".html";

    open(my $fh, '>', $file);
    print($fh $html);
    close($fh);

    my $msg = $url . $name . ".html";
    return $msg;
}

sub file_remove {
    my $name = shift;
    my $file = $filepath . $name . ".html";

    my $msg;
    if (-f $file){
        unlink($file);
        $msg = $url . $name . ".html";
        $msg = "FILE DETETE: " . $url . $name . ".html";
    }
    else {
        $msg = "FILE NOTHING: " . $url . $name . ".html";
    }
    return $msg;
}


sub add_scatter {
    my ($name, $concurrency, $score) = @_;
    $r->hset($name, $concurrency, $score);

    createe_scatter_view($name, $concurrency, $score);
}

sub delete_scatter {
    my ($name, $concurrency, $score) = @_;
    $r->hdel($name, $concurrency, $score);

    if (0 < $r->hlen($name)){
        createe_scatter_view($name, $concurrency, $score);
    }
    else
    {
        file_remove($name);
    }
}

sub all_delete_scatter {
    my $name = shift;
    $r->del($name);

    file_remove($name);
}

1;

__DATA__

@@ template.tx
<html>
  <head>
    <script type="text/javascript" src="https://www.google.com/jsapi"></script>
    <script type="text/javascript">
      google.load("visualization", "1", {packages:["corechart"]});
      google.setOnLoadCallback(drawChart);
      function drawChart() {
        var data = google.visualization.arrayToDataTable([
          ['concurrency', 'score'],
: for $data.keys() -> $d {
          [ <: $d :>, <: $data[$d] :> ],
: }
        ]);

        var options = {
        title: '<: $name :> benchmark',
          hAxis: {title: 'concurrency', minValue: 0, maxValue: 15},
          vAxis: {title: 'score', minValue: 0, maxValue: 15},
          legend: 'none'
        };

        var chart = new google.visualization.ScatterChart(document.getElementById('chart_div'));
        chart.draw(data, options);
      }
    </script>
  </head>
  <body>
    <div id="chart_div" style="width: 900px; height: 500px;"></div>
  </body>
</html>
