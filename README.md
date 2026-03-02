# Prometheus generic exporter

This exporter lets you fetch data from a bunch of endpoints and expose desired data as metrics that can be consumed by prometheus.

## Usage

### Using docker

Docker images are kept in sync releases from github.
The image expects to have a config.yml file in /config folder.

```
docker run -it -v $PWD:/config krisboit/prom-generic-exporter:latest
```

To run the exporter with config file from a custom path, run:

```bash
docker run -it krisboit/prom-generic-exporter:latest node /app/index.js <path to config file>
```

### Prebuild version (linux-x64)

Go to: [Releases page](https://github.com/MoonletLabs/prom-generic-exporter/releases) and download the latest version.

_**Note:** you don't need nodeJS to run it._

Run command:

```bash
$ prom-generic-exporter <path to config.yml>
```

### Building from source

#### Prerequisites

To build the project you need [NodeJS](https://nodejs.org/en/download/) and [pnpm](https://pnpm.io/installation).
To simply install pnpm run:

```bash
npm install -g pnpm # to install pnpm,
```

or go to https://pnpm.io/installation for other instalation methods.

#### Build Project

```bash
pnpm install # fetch project dependencies
pnpm run build # builds the project
```

#### Run project

```
node build/index.js <path to config.yml>
```

## Config file

Right now the exporter support only YML format for config.

Config file has 4 main sections:

### General configs (optional)

All configs in general are optional, and bellow you can see default values

```yml
---
general:
  port: 9975 # port to listen on
  path: /metrics # path where the metrics will be exposed
```

### Data sources

Right now there are 3 data sources implementations:

#### JSON

With this data source you can fetch data from a rest api that will return a JSON response.
Properties:

- method?: "post" | "get"; // optional

  Request method, possible values: get and post.
  Default value: get

- url: string; // required

  Request url. e.g. https://example.com/some-data

- body?: Object; // optional

  Request body. An object with the body, it will serialize as JSON string and send it on the request with 'Content-type: application/json' header.
  Default value: It will not send request body.

- interval: string; // required

  On what interval to refresh data. It has support for seconds, minutes and hours. e.g. 1s, 10s, 15m, 5m, 12h, 18h, 24h etc.

Simple example:

```yml
data:
  myDataKey:
    type: json
    url: https://example.com/some-data
    interval: 15s
  myComplexDataKey:
    type: json
    method: post
    url: https://example.com/some-post-data
    body:
      someInputKey: someValue
      anArray:
        - first value
        - second values
    interval: 15m
```

#### JSONRPC

This one is just a wrapper over JSON to facilitate jsonrpc calls. It will always send post request with a jsonrpc v2 body.

Properties:

- url: string; // required

  jsonrpc endpoint.

- method: string; // required

  jsonrpc method (not request method) that you want to invoke over rpc

- params?: any; // optional

  json rpc params. If not presend in config it will not send params at all. So if a empty array or object is needed set like this:

  ```yml
  params: [] # for array
  params: {} # for object
  ```

- interval: string; // required

  Same as JSON data type.

Simple example:

```yml
data:
  myDataKey:
    type: jsonrpc
    url: https://example.com/rpc
    method: eth_getBlock
    params: []
    interval: 15s
  myComplexDataKey:
    type: jsonrpc
    method: eth_getBalance
    url: https://example.com/rpc
    params:
      - 0x12345
      - latest
    interval: 15m
```

#### SHELL

**Not implemented yet**

#### Examples:

### Metrics

Here you will expose data fetched in `data` section as metrics. The exported uses prom-client behind the scene.

Poperties:

- type: "counter" | "gauge" | "histogram" | "summary";

  Metric type, supported options are counter, gauge, histogram and summary.

- help?: string;

  Help text for a metric.

- labels?: string[];

  Metric supported labels.

- buckets?: number[];

  Metric buckets.

- values:

  Metric value. Here there are a lot of options. Examples:

  - simple value no labels:

  ```yml
  values:
    - value: $data.myDataKey.data.someKey
  ```

  **$data** - object with results from all data sources defined in `data` section
  **myDataKey** - name of data source defined in `data` section
  **myDataKey.data** - response data from datasource defined in `data`, in future other values might appear here (like: responseHeaders, responseStatus, etc...)

  - simple value with labels:

  ```yml
  data:
    ethBalance:
      type: jsonrpc
      url: https://mainnet.infura.io/v3/...
      method: eth_getBalance
      params:
        - "0x6aaafD4BeeE6137036e0367B1C5a89Bb514f3EB1"
        - latest
      interval: 15s
  metrics:
    balance:
      type: gauge
      help: "ETH balance test"
      labels:
        - address
      values:
        - labels:
            address: $config.ethBalance.params[0]
            value: fromAtomic(fromHex($data.ethBalance.data.result),18)
  ```

  **$config** - reference to `data` config object
  **$helpers** - object with js functions that can be used to proccess data (see Helpers section)

  - values with loops

  ```yml
  data:
    loopTest:
      type: json
      url: https://rpc.mainnet.near.org/status
      interval: 15s
  metrics:
    is_slashed:
      type: gauge
      help: "Loop test"
      labels:
        - account_id
      values:
        - loop:
            on: $data.loopTest.data.validators
            values:
              - labels:
                  account_id: $item.account_id
                value: "$item.is_slashed ? 1 : 0"
  ```

  - values with loops and filtering

  ```yml
  data:
    loopTest:
      type: json
      url: https://rpc.mainnet.near.org/status
      interval: 15s
  metrics:
    is_slashed:
      type: gauge
      help: "Loop test"
      labels:
        - account_id
      values:
        - loop:
            on: $data.loopTest.data.validators
            as: $node
            where: "$node.account_id === 'moonlet.poolv1.near'"
            values:
              - labels:
                  account_id: $node.account_id
                value: "$node.is_slashed ? 1 : 0"
  ```

### Helpers

Builtin helpers:

- fromAtomic(amount, decimals) - e.g. amount = 1000000, decimals = 6 => fromAtomic(amount, decimals) = 1
- toAtomic(amount, decimals) - e.g. amount = 1, decimals = 6 => fromAtomic(amount, decimals) = 1000000
- fromHex(data) - converts from hex to decimal

To extend with your own helpers add a `helpers` section. Example:

```yml
helpers:
  - /config/myhelpers.js
```

Helper file example:

```js
module.exports = {
  percent: (input, max) => Math.round((input / max) * 100, 2),
  otherExample: function (param) {
    return parseInt(param) + 1;
  }
};
```

These helpers can be used in config as: `$helpers.percent(...)` and `$helpers.otherExample(...)`

