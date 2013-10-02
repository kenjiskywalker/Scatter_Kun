
## これは何ですか

これはIRC botで、`操作`、`ファイル名`、`値1`、`値2`を渡すことで  
`ファイル名`に`値1`、`値2`の数値を利用し、分布図っぽい画像を生成します。  
画像生成するにあたり、Redisのhash機能を利用します。

## 例

### IRCの設定

```
my $unazu_san = UnazuSan->new(
    nickname      => 'scatter_kun',
    host          => 'irc.freenode.net',
    password      => '',
    join_channels => [qw/kenjiskywalker/],
    enable_ssl    => 0,
);
```


### scatter_kunの設定

```
my $url          = "http://www.kenjiskywalker.org/scatter/";
my $filepath     = "/home/skywalker/www/scatter/";
my $scatter_name = "benchmark";
my $key_name     = "concurrency";
my $value_name   = "score";
```

- `url` - ブラウザでアクセスする場合のURLを指定します。これはbotのレスポンスメッセージに利用されます。
- `filepath` HTMLを吐き出すディレクトリを指定します。これはHTML生成時に利用します。
- `$scatter_name` グラフの名前を指定します。これはHTML生成時に利用します。
- `$key_name` グラフのkey名を指定します。これはHTML生成時に利用します。
- `$value_name` グラフのvalue名を指定します。これはHTML生成時に利用します。


```
24:00 kenjiskywalker_: scatter_kun:
24:00 scatter_kun: state[ADD|DEL|ALLDEL] hoge[graph_name] n[key] m[value]
```

### testgraphのグラフが新規である場合はファイルを生成します

```
24:00 kenjiskywalker_: scatter_kun: ADD testgraph 10 100
24:00 scatter_kun: ADD testgraph 10 100
24:00 scatter_kun: FILE CREATE: http://www.kenjiskywalker.org/scatter/testgraph.html
```

![https://dl.dropboxusercontent.com/u/5390179/testgraph.png](https://dl.dropboxusercontent.com/u/5390179/testgraph.png)

### 同じファイルに別の値を追加します

```
24:00 kenjiskywalker_: scatter_kun: ADD testgraph 20 100
24:00 scatter_kun: ADD testgraph 20 100
24:00 scatter_kun: ADD: http://www.kenjiskywalker.org/scatter/testgraph.html
```

![https://dl.dropboxusercontent.com/u/5390179/testgraph.png](https://dl.dropboxusercontent.com/u/5390179/testgraph2.png)

### 値を削除します

```
24:00 kenjiskywalker_: scatter_kun: DEL testgraph 10 100
24:00 scatter_kun: DEL  testgraph 10 100
24:00 scatter_kun: ADD: http://www.kenjiskywalker.org/scatter/testgraph.html
```

ファイルのデータが空になるか、`ALLDEL`でデータを全削除するとファイルも削除されます。

![https://dl.dropboxusercontent.com/u/5390179/testgraph.png](https://dl.dropboxusercontent.com/u/5390179/testgraph3.png)


```
24:00 kenjiskywalker_: scatter_kun: ALLDEL testgraph
24:00 scatter_kun: FILE DETETE: http://www.kenjiskywalker.org/scatter/testgraph.html
```
