# MoonTide 参赛说明

## 项目定位

MoonTide 是一个使用 MoonBit 编写的本地优先潮汐预测和海岸活动建议工具。核心价值不只是输出潮高，而是提供一条可审计的真实站点接入路径：解析权威站点数据、映射调和常数、统一垂直基准、预测潮高、与权威预测对照，并明确报告未覆盖分潮和适用边界。

## 对初审意见的补充

初审提出两点：真实站点常数兼容，以及潮汐预测适用边界。当前仓库已经补齐以下工程范围。

### 1. 真实站点常数兼容

支持 NOAA CO-OPS JSON：

- 站点元数据
- 调和常数
- 已发布基准面
- 官方逐时预测

真实验证站点为 `8518750`：The Battery, New York。

### 2. 核心处理机制

1. 从 NOAA metadata 解析站点 ID、名称、纬度和经度。
2. 从 NOAA harmonic constituents 读取分潮名称、振幅和 GMT 相位。
3. 按名称映射到 MoonTide 的支持目录；当前支持 M2、S2、N2、K2、K1、O1、P1、Q1、M4、MS4、M6。
4. 将未映射分潮返回并打印，避免静默遗漏。
5. 将 MSL 基准的调和常数转换到 NOAA 预测使用的 MLLW 基准，本案例偏移为 `1.785 - 1.002 = 0.783 m`。
6. 用天文参数、平衡潮角、结点改正和调和求和计算潮高。
7. 将 MoonTide 逐时结果与 NOAA 预测比较，计算 Bias、MAE、RMSE 和最大绝对误差。

### 3. 权威预测对照案例

运行：

```bash
moon run cmd/moontide --target wasm-gc -- validate-reference \
  --metadata validation/noaa-8518750/metadata.json \
  --harcon validation/noaa-8518750/harcon.json \
  --datums validation/noaa-8518750/datums.json \
  --predictions validation/noaa-8518750/predictions-20261012-20261015.json \
  --tolerance 0.12
```

结果：

- 站点：NOAA 8518750, The Battery
- 官方分潮：37 个
- MoonTide 使用：11 个
- 未纳入：26 个，并在 CLI 中逐项列出
- 对照样本：2026-10-12 至 2026-10-15，逐小时，共 96 个
- Bias：`-0.08 m`
- MAE：`0.09 m`
- RMSE：`0.10 m`
- 最大绝对误差：`0.20 m`
- 结果：`PASS`

离线 fixture 和来源链接位于 `validation/noaa-8518750/`。`validate-reference` 在误差超过阈值时非零退出，CI 会拦截回归。

### 4. 适用边界

MoonTide 当前只覆盖调和潮汐预测，不包含风暴增水、海啸、河流径流、波浪爬高、冰情、长期海平面变化或局部工程改造。它不用于导航、海上作业、救援或者其他安全关键决策。

精度受站点常数质量、分潮覆盖、基准面一致性、常数适用年份和非线性项完整性影响。内置 `demo`、`qingdao`、`xiamen` 常数只用于 CLI 演示；真实使用应采用可追溯数据并运行外部对照。

## 验收对照

- MoonBit 主要实现：核心算法、数据模型、验证逻辑、导出和 CLI 均为 MoonBit。
- 工具链：要求 `moonc >= 0.10.14`；当前在 `moonc v0.10.15+943464bfa` 通过。
- 公开仓库：`https://github.com/WYT-ai-nb/moontide`
- README：包含安装、使用、示例、NOAA 对照、机制、边界、测试和代码结构。
- 可运行示例：`predict`、`stats`、`events`、`curve`、`plan`、`export` 和 `validate-reference`。
- 测试：27 项自动化测试覆盖核心计算、解析、统计、导出、站点检索和 NOAA 验证。
- CI：GitHub Actions 覆盖检查、构建、测试、最小示例和 96 点 NOAA 对照。
- mooncakes.io：项目已按验收要求发布和更新。
- 许可证：Apache-2.0。

## 仓库

https://github.com/WYT-ai-nb/moontide
