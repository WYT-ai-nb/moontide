# MoonTide

MoonTide 是一个使用 MoonBit 编写的本地优先潮汐预测工具。它把站点数据接入、调和常数换算、潮高预测、权威预测对照、边界报告和 CLI 输出放在同一个可测试工程中，既能直接生成潮汐信息，也能作为其他 MoonBit 项目复用潮汐计算的参考实现。

## 项目目标

MoonTide 解决三个具体问题：

1. 让真实潮汐站的元数据、调和常数和基准面数据可以直接进入计算流程。
2. 让预测结果能够与权威机构发布的预测做逐时对照，而不是只展示内置演示数据。
3. 让误差、分潮覆盖率和适用边界显式暴露，避免把科研或安全场景误用在普通活动建议之上。

## 为什么对 MoonBit 生态有用

- **真实数据接入**：已经支持 NOAA CO-OPS 的站点元数据、调和常数、基准面和预测 JSON。
- **可复现验证**：离线保存真实站点 fixture，并用 `validate-reference` 命令与 NOAA 预测逐时比较。
- **数值计算示例**：覆盖儒略日、天文参数、Doodson 数、结点改正、调和分潮求和和误差统计。
- **工程化交付**：包含库 API、CLI、JSON、Markdown、CSV、iCalendar、ASCII 曲线和 CI。
- **边界清晰**：未支持的 NOAA 分潮会被显式列出，不会悄悄把未知常数当作已支持分潮。

## 快速开始

要求 `moonc >= 0.10.14`。当前验证使用：

```text
moon 0.1.20261012
moonc v0.10.15+943464bfa
```

克隆、检查和测试：

```bash
git clone https://github.com/WYT-ai-nb/moontide.git
cd moontide
moon version --all
moon check --target wasm-gc
moon test --target wasm-gc
moon build --target wasm-gc
```

运行最小示例：

```bash
moon run cmd/moontide --target wasm-gc -- predict \
  --station demo \
  --date 2026-10-12 \
  --tz 8 \
  --hours 24
```

## CLI

```text
moontide list
moontide validate --station demo
moontide predict --station demo --date 2026-10-12 --tz 8 --hours 24
moontide stats --station demo --date 2026-10-12 --hours 48
moontide events --station demo --date 2026-10-12 --format csv
moontide curve --station demo --date 2026-10-12
moontide plan --station demo --date 2026-10-12
moontide export --station demo --date 2026-10-12 --format ics
moontide validate-reference \
  --metadata validation/noaa-8518750/metadata.json \
  --harcon validation/noaa-8518750/harcon.json \
  --datums validation/noaa-8518750/datums.json \
  --predictions validation/noaa-8518750/predictions-20261012-20261015.json \
  --tolerance 0.12
```

常用参数：

- `--station <id>`：内置示例站点 `demo`、`qingdao`、`xiamen`
- `--date <YYYY-MM-DD>`：预测起始日期
- `--tz <offset>`：UTC 偏移小时数，默认 `8`
- `--hours <n>`：预测时长，默认 `24`
- `--format <markdown|json|csv|ics>`：输出格式
- `--tolerance <m>`：NOAA 对照的平均绝对误差阈值，默认 `0.3 m`

## 真实站点兼容与权威对照

验证案例使用 NOAA CO-OPS 站点 `8518750`：The Battery, New York。

- 站点中心：40.700554, -74.01417
- 官方调和常数：37 个
- MoonTide 当前使用：11 个
- 当前未纳入：26 个
- 基准面：NOAA 预测使用 MLLW
- 调和常数：NOAA 常数使用 MSL
- 基准换算：`MSL - MLLW = 1.785 - 1.002 = 0.783 m`
- 对照区间：2026-10-12 至 2026-10-15，逐小时，共 96 个样本

运行：

```bash
moon run cmd/moontide --target wasm-gc -- validate-reference \
  --metadata validation/noaa-8518750/metadata.json \
  --harcon validation/noaa-8518750/harcon.json \
  --datums validation/noaa-8518750/datums.json \
  --predictions validation/noaa-8518750/predictions-20261012-20261015.json \
  --tolerance 0.12
```

当前输出：

```text
# MoonTide NOAA Validation

- Station: The Battery (8518750)
- Source: NOAA CO-OPS station 8518750; harmonic constants + published datums
- Datum offset (MSL - MLLW): 0.78 m
- Harmonic constituents: 37 total, 11 used, 26 ignored
- Ignored by the current catalog: MK3, S4, MN4, NU2, S6, MU2, 2N2, OO1, LAM2, S1, M1, J1, MM, SSA, SA, MSF, MF, RHO, T2, R2, 2Q1, 2SM2, M3, L2, 2MK3, M8
- Samples: 96
- Bias: -0.08 m
- Mean absolute error: 0.09 m
- Root mean square error: 0.10 m
- Maximum absolute error: 0.20 m
- Mean-error tolerance: 0.12 m
- Result: **PASS**
```

更精确的内部统计值为：

- Bias：约 `-0.0845 m`
- MAE：约 `0.0883 m`
- RMSE：约 `0.1036 m`
- 最大绝对误差：约 `0.1959 m`

当平均绝对误差超过 `--tolerance` 时，命令会以非零状态退出，CI 会失败。NOAA 数据来源和下载地址记录在 `validation/noaa-8518750/SOURCE.md`。

## 核心处理机制

1. **站点元数据解析**：从 NOAA metadata JSON 读取站点 ID、名称、纬度和经度。
2. **调和常数映射**：读取 NOAA `HarmonicConstituents`，按名称映射到 MoonTide 内置分潮目录；当前目录包含 M2、S2、N2、K2、K1、O1、P1、Q1、M4、MS4、M6。
3. **分潮覆盖审计**：未映射的 NOAA 分潮由 `noaa_unsupported_constituents` 返回，并在 CLI 输出中列出，防止静默丢失。
4. **基准面归一化**：NOAA 调和常数以 MSL 为基准，预测 API 使用 MLLW；MoonTide 使用已发布的 MSL 和 MLLW 数值计算偏移量，并把它作为站点的垂直基准。
5. **调和预测**：使用 J2000 起算的天文参数，计算平衡潮角、结点因子、结点角和各分潮贡献，再叠加站点基准得到潮高。
6. **权威预测对照**：逐时读取 NOAA 预测 JSON，与 MoonTide 结果计算 Bias、MAE、RMSE 和最大绝对误差。
7. **验收闸门**：`validate-reference` 在平均误差不达标时失败退出，CI 自动验证真实站点案例。

## 精度与适用边界

MoonTide 当前是调和潮汐预测器，不是完整海洋动力模型，也不包含：

- 风暴增水、海啸、河流径流、波浪爬高和冰情
- 长期海平面变化和局部港口工程改造影响
- 导航、海上作业、救援和其他安全关键决策

精度取决于站点调和常数质量、分潮覆盖范围、数据和预测是否使用相同基准面、常数适用的 epoch/年份，以及非线性分潮和季节项是否完整。内置 `demo`、`qingdao` 和 `xiamen` 站点只用于演示 CLI，不代表官方常数；真实使用应像 NOAA 案例一样提供可追溯数据并运行对照验证。

## 测试与 CI

当前包含 27 项自动化测试，覆盖：

- 天文参数、分潮速度和结点改正
- 儒略日和日期时间转换
- 极值查找、潮汐统计和时间窗规划
- CSV、ICS、Markdown 和 JSON 输出
- NOAA 站点、调和常数、基准面和预测 JSON 解析
- NOAA 分潮覆盖审计
- MoonTide 对 NOAA 前 24 个逐时点的误差断言

CI 位于 `.github/workflows/ci.yml`，覆盖检查、构建、测试、最小示例和完整 96 点 NOAA 对照。

## 代码规模与结构

当前有效非测试 MoonBit 源码约 2769 行，其中非空且非注释代码约 2346 行。测试源码约 376 行。

```text
moontide/
  astro.mbt            天文基本参数
  time.mbt             儒略日、日期转换和本地时间
  constituent.mbt      分潮定义和速度
  harmonic.mbt         平衡潮角、结点改正和潮高计算
  station.mbt          站点模型与示例站点
  noaa.mbt             NOAA 数据接入、误差统计和验证报告
  extreme.mbt          高低潮查找
  analysis.mbt         潮汐状态、速率、统计和时间窗
  planner.mbt          活动评分和推荐计划
  exporter.mbt         CSV、ICS 和 Markdown 导出
  validation.mbt       站点与参数校验
  station_search.mbt   距离计算、站点检索和质量评分
  solar.mbt            日出日落近似
  activity.mbt         活动推荐规则
  render.mbt           Markdown、JSON 和 ASCII 曲线
  moontide.mbt         高层预测接口
  cmd/moontide/        CLI 入口
  validation/          NOAA 离线验证数据
```

## 许可证

Apache-2.0。NOAA 数据来源和日期记录在 `validation/noaa-8518750/SOURCE.md`。
