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

my $url          = "http://www.kenjiskywalker.org/scatter/";
my $filepath     = "/home/skywalker/www/scatter/";
my $scatter_name = "benchmark";
my $key_name     = "concurrency";
my $value_name   = "score";


$unazu_san->on_message(
    qr/^$unazu_san->{nickname}:\s+([\w\-.]+)\s+([\w\-.]+)\s+([\d\-.]+)\s+([\d\-.]+)/ => sub {
        my ($receive, $state, $name, $key, $value) = @_;

        if ($state eq "ADD") {
            warn "ADD";
            my $msg = add_scatter($name, $key, $value);
            warn $msg;

            $receive->reply("ADD"." ".$name." ".$key." ".$value);
            $receive->reply("$msg");
        }
        elsif ($state eq "DEL") {
            warn "DEL";
            my $msg = delete_scatter($name, $key, $value);
            warn $msg;

            $receive->reply("DEL "." ".$name." ".$key." ".$value);
            $receive->reply("$msg");
        }
        else {
            warn "ELSE";
            $receive = shift;
            $receive->reply('state[ADD|DEL|ALLDEL] hoge[graph_name] n[key] m[value]');
        }
    },
    qr/^$unazu_san->{nickname}:\s+([\w\-.]+)\s+([\w\-.]+)/ => sub {
        my ($receive, $state, $name, $key, $value) = @_;
        if ($state eq "ALLDEL") {
            warn "ALLDEL";
            my $msg = all_delete_scatter($name);
            warn $msg;
            $receive->reply($msg);
        }
        else {
            warn "ELSE";
            $receive = shift;
            $receive->reply('state[ADD|DEL|ALLDEL] hoge[graph_name] n[key] m[value]');
        }
    },
    qr/^$unazu_san->{nickname}:/ => sub {
        my ($receive, $match) = @_;
        $receive = shift;
        $receive->reply('state[ADD|DEL|ALLDEL] hoge[graph_name] n[key] m[value]');
    },
);

$unazu_san->run;

sub create_scatter_view {
    my ($name, $key, $value) = @_;

    my $vpath = Data::Section::Simple->new()->get_data_section();
    my $tx    = Text::Xslate->new(path => [$vpath]);

    my @key_list = $r->hkeys($name);

    my %name_keys_values;
    for my $key (@key_list){
        my $value = $r->hget($name, $key);
        $name_keys_values{"$key"} = $value;
    }

    my $html = $tx->render("template.tx",
        {
            scatter_name => $scatter_name,
            key_name     => $key_name,
            value_name   => $value_name,
            name         => $name,
            data         => \%name_keys_values,
        }
    );

    my $file = $filepath . $name.".html";

    my $msg;
    if (-f $file){
        $msg = "ADD: " . $url . $name . ".html";
    }
    else {
        $msg = "FILE CREATE: " . $url . $name . ".html";
    }

    open my $fh, '>', $file or die $!;
    print($fh $html);
    close $fh or die $!;

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
    my ($name, $key, $value) = @_;

    if ( $value eq $r->hget($name, $key) ) {
        my $msg = "DATA EXIST: " . $url . $name . ".html";
        return $msg;
    }

    $r->hset($name, $key, $value);
    create_scatter_view($name, $key, $value);
}

sub delete_scatter {
    my ($name, $key, $value) = @_;
    $r->hdel($name, $key, $value);

    if (0 < $r->hlen($name)){
        create_scatter_view($name, $key, $value);
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
          ['<: $key_name :>', '<: $value_name :>'],
: for $data.keys() -> $d {
          [ <: $d :>, <: $data[$d] :> ],
: }
        ]);

        var options = {
        title: '<: $name :> <: $scatter_name :> ',
          hAxis: {title: '<: $key_name :>', minValue: 0, maxValue: 15},
          vAxis: {title: '<: $value_name :>', minValue: 0, maxValue: 15},
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
