# Changelog

## [1.4.0](https://github.com/JPaiv/aws-eks-clickhouse/compare/v1.3.1...v1.4.0) (2026-07-24)


### Features

* ack s3 controller onboarded from git ([ec379e5](https://github.com/JPaiv/aws-eks-clickhouse/commit/ec379e5bbb3f0c28a38bb8dd4ba6c9df99e1bbfd))
* ack s3 controller onboarded from git ([352df66](https://github.com/JPaiv/aws-eks-clickhouse/commit/352df66abde3a9b0527437eb5fb7b065720743e3))

## [1.3.1](https://github.com/JPaiv/aws-eks-clickhouse/compare/v1.3.0...v1.3.1) (2026-07-23)


### Bug Fixes

* minDomains forces the keeper quorum across three zones ([8f7918b](https://github.com/JPaiv/aws-eks-clickhouse/commit/8f7918baed1796357d41eabb926bd9ca6b4d4af4))
* minDomains forces the keeper quorum across three zones ([125af4e](https://github.com/JPaiv/aws-eks-clickhouse/commit/125af4ef8c69edf08149f8349ae35793f1e3118d))
* operator installs into the clickhouse namespace ([ee387ea](https://github.com/JPaiv/aws-eks-clickhouse/commit/ee387eaf2bb743d9f9a6048688e70b12d275bc01))
* operator installs into the clickhouse namespace ([e09b0d6](https://github.com/JPaiv/aws-eks-clickhouse/commit/e09b0d645a68d7cede3dbe0c9e95cec6839316f1))
* short helm release name for the operator chart ([5cbce20](https://github.com/JPaiv/aws-eks-clickhouse/commit/5cbce202e2b8739cc34f93d33b3969def1481d69))
* short helm release name for the operator chart ([a872094](https://github.com/JPaiv/aws-eks-clickhouse/commit/a8720949b727351b4a5b1134f8550d5f3a92c31d))

## [1.3.0](https://github.com/JPaiv/aws-eks-clickhouse/compare/v1.2.4...v1.3.0) (2026-07-23)


### Features

* clickhouse operator on every spoke, keeper quorum in the baseline ([f669e2e](https://github.com/JPaiv/aws-eks-clickhouse/commit/f669e2e103f97c046d97a28b85e0b2e88f6c0bd7))
* clickhouse operator on every spoke, keeper quorum in the baseline ([cf59466](https://github.com/JPaiv/aws-eks-clickhouse/commit/cf594666865e6032d77ad4430aea9856f8ba4c0b))


### Bug Fixes

* pin the spoke registration to its real ca ([0d19ce1](https://github.com/JPaiv/aws-eks-clickhouse/commit/0d19ce1192c11fa767db8336b27093a8664db010))
* pin the spoke registration to its real ca ([aed2235](https://github.com/JPaiv/aws-eks-clickhouse/commit/aed2235180894dc20982c0833901dfe508172254))
* server-side apply for the operator chart ([df8de17](https://github.com/JPaiv/aws-eks-clickhouse/commit/df8de1733c5956c5821ac62cf55c98af7fe8e8d3))
* server-side apply for the operator chart ([a98089c](https://github.com/JPaiv/aws-eks-clickhouse/commit/a98089c266fafe71464c6a05e21e41ee4143ffe9))

## [1.2.4](https://github.com/JPaiv/aws-eks-clickhouse/compare/v1.2.3...v1.2.4) (2026-07-23)


### Bug Fixes

* stop committing the cluster secret's server key ([178daa9](https://github.com/JPaiv/aws-eks-clickhouse/commit/178daa9a881c7cfa5918e9660d29e01dec28446d))
* stop committing the cluster secret's server key ([e139652](https://github.com/JPaiv/aws-eks-clickhouse/commit/e139652d78b8d2847e7f451b3c0e9025ad8c5dee))

## [1.2.3](https://github.com/JPaiv/aws-eks-clickhouse/compare/v1.2.2...v1.2.3) (2026-07-23)


### Bug Fixes

* admit the hub to spoke API endpoints via a shared SG ([1996241](https://github.com/JPaiv/aws-eks-clickhouse/commit/19962417be84d8bd6cd1fe9dd2838b007fbd5e94))
* admit the hub to spoke API endpoints via a shared SG ([042f173](https://github.com/JPaiv/aws-eks-clickhouse/commit/042f173bdc9de26dec39839c501c0d72930b6f66))

## [1.2.2](https://github.com/JPaiv/aws-eks-clickhouse/compare/v1.2.1...v1.2.2) (2026-07-23)


### Bug Fixes

* pass Auto Mode node role to ec2.amazonaws.com, spoke on 1.36 ([4594e7c](https://github.com/JPaiv/aws-eks-clickhouse/commit/4594e7ca668c0060fe8b02a595779be8a8dbe414))
* tag actions authorize on the tagged resource's own ARN ([c63a6a3](https://github.com/JPaiv/aws-eks-clickhouse/commit/c63a6a3ed4a6370fb4b6f3a8e5a14e0e706d9ea4))
* tag actions authorize on the tagged resource's own ARN ([a46a860](https://github.com/JPaiv/aws-eks-clickhouse/commit/a46a860724eee5b0b0188bbc229c5946d88f2309))

## [1.2.1](https://github.com/JPaiv/aws-eks-clickhouse/compare/v1.2.0...v1.2.1) (2026-07-23)


### Bug Fixes

* pass Auto Mode node role to ec2.amazonaws.com, spoke on 1.36 ([a8ca1a3](https://github.com/JPaiv/aws-eks-clickhouse/commit/a8ca1a394ca1a36271ff660b7c4f056ddecae97e))
* pass Auto Mode node role to ec2.amazonaws.com, spoke on 1.36 ([dca7b90](https://github.com/JPaiv/aws-eks-clickhouse/commit/dca7b9014e43293cff176b34d9f5ef7221d552a3))

## [1.2.0](https://github.com/JPaiv/aws-eks-clickhouse/compare/v1.1.0...v1.2.0) (2026-07-23)


### Features

* fill dev-clickhouse spoke placeholders from bootstrap outputs ([273cbe6](https://github.com/JPaiv/aws-eks-clickhouse/commit/273cbe6f627d8fba131df39e8f840c2cae8f56fc))
* fill dev-clickhouse spoke placeholders from bootstrap outputs ([98dd10d](https://github.com/JPaiv/aws-eks-clickhouse/commit/98dd10dee13d154141fed0604f5c25689fa25b09))

## [1.1.0](https://github.com/JPaiv/aws-eks-clickhouse/compare/v1.0.0...v1.1.0) (2026-07-22)


### Features

* bootstrap argo cd and the ack identity fixed point ([05bb271](https://github.com/JPaiv/aws-eks-clickhouse/commit/05bb27181563fff4cda9e703a9618f04c893e8a6))
* bootstrap argo cd and the ack identity fixed point ([6d73315](https://github.com/JPaiv/aws-eks-clickhouse/commit/6d733151da227adb23e823569510ec548048e139))
* hub-and-spoke fleet with first spoke as git manifests ([431a99c](https://github.com/JPaiv/aws-eks-clickhouse/commit/431a99cf72d56bc4c886285d89f7bfd6761484c7))
* hub-and-spoke fleet with first spoke as git manifests ([8be3026](https://github.com/JPaiv/aws-eks-clickhouse/commit/8be3026f14745929db5a58243597f673e2122976))

## 1.0.0 (2026-07-22)


### Features

* bootstrap the repository toolchain and workflow ([f091659](https://github.com/JPaiv/aws-eks-clickhouse/commit/f09165910cffd8358744362260937aedf654cf23))
* bootstrap the repository toolchain and workflow ([8fce7f3](https://github.com/JPaiv/aws-eks-clickhouse/commit/8fce7f31ff19c7efd57d7e53140fa9a00d8b8f51))
* scaffold remote state, network and eks bootstrap stacks ([ff8411b](https://github.com/JPaiv/aws-eks-clickhouse/commit/ff8411b10029adbab73d2452330a367e9155330b))
* scaffold remote state, network and eks bootstrap stacks ([407cb28](https://github.com/JPaiv/aws-eks-clickhouse/commit/407cb282d67447e3150bf314103496d9f4fb6548))
