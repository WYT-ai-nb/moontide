# MoonTide

MoonTide 是一个本地优先的潮汐预测和海岸活动建议工具，使用 MoonBit 编写。它用天文参数和调和分析计算潮汐曲线、高低潮时间，并给出赶海、钓鱼、观鸟建议。

## 为什么做这个

潮汐直接影响海边居民、渔民、摄影师和户外爱好者，但通用天气软件往往只给出笼统的海浪信息。MoonTide 把预测过程留在本地，输入日期和站点即可得到：

- 高低潮时刻和潮高
- 当日潮差、大潮/中潮/小潮判断
- 日出日落近似时间
- 赶海、钓鱼、观鸟建议
- ASCII 潮汐曲线

## 快速开始

```bash
git clone https://github.com/WYT-ai-nb/moontide.git
cd moontide
moon test
moon run cmd/moontide -- list
moon run cmd/moontide -- predict --station demo --date 2026-10-12 --tz 8 --hours 24
```

## CLI

```text
moontide list
moontide predict --station demo --date 2026-10-12 --tz 8 --hours 24
```

选项：

- `--station <id>`：内置站点 `demo`、`qingdao`、`xiamen`
- `--date <YYYY-MM-DD>`：预测起始日期，默认 `2026-10-12`
- `--tz <offset>`：UTC 偏移小时数，默认 `8`
- `--hours <n>`：预测时长小时数，默认 `24`
- `--format <markdown|json>`：输出格式

## 站点数据

`sample/qingdao.json` 展示了站点调和常数的标准 JSON 字段。`amplitude` 是分潮振幅（米），`phase` 是格林尼治迟角（度），`datum` 是平均海平面：

```json
{
  "id": "myport",
  "name": "我的港口",
  "lat": 31.23,
  "lon": 121.47,
  "datum": 0.0,
  "source": "本地《潮汐表》调和常数",
  "components": [
    {"name": "M2", "amplitude": 1.31, "phase": 305.0},
    {"name": "S2", "amplitude": 0.43, "phase": 342.0},
    {"name": "K1", "amplitude": 0.26, "phase": 172.0},
    {"name": "O1", "amplitude": 0.19, "phase": 210.0}
  ]
}
```

## 项目结构

```text
moontide/
  astro.mbt          天文基本参数
  time.mbt           儒略日、日历转换、本地时间
  constituent.mbt    分潮定义
  harmonic.mbt       调和分析、结点改正
  station.mbt        站点和站点文件解析
  extreme.mbt        高低潮查找
  solar.mbt          日出日落近似
  activity.mbt       活动推荐规则
  render.mbt         Markdown/JSON 和 ASCII 曲线
  moontide.mbt       高层预测接口
  cmd/moontide/      CLI 入口
```

## 验证与精度说明

当前内置站点的调和常数是**演示数据**，不是官方发布的真实常数。正式使用前请替换为当地《潮汐表》或海洋站发布的调和常数，并在 `README` 或测试中记录对照误差。MoonTide 只做预测计算，不负责导航、海上作业或其他安全决策。

## 许可证

Apache-2.0
