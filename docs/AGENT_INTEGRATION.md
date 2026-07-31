# 外部 Agent 接入协议

PaperPrism 的公开版不绑定任何模型服务商。它把用户选择的命令行程序视为一个可替换的 Agent 适配器。

## 进程约定

1. 在设置中选择一个本机可执行文件。
2. “启动参数”中每个非空行会作为一个独立参数原样传递。
3. 参数中的 `{paperPath}` 与 `{paperTitle}` 会分别替换为当前论文路径和标题。
4. PaperPrism 将完整任务提示写入进程的标准输入，然后关闭输入流。
5. 进程必须把最终 JSON 写入标准输出；诊断和进度日志写入标准错误。
6. 退出码 `0` 表示成功，非零退出码会显示为任务失败。
7. 工作目录是当前论文文件所在目录。

不要把密钥写进启动参数。建议使用 Agent 自己的登录机制、系统钥匙串或它支持的环境配置。

## 精读结果

```json
{
  "translation": "中文翻译",
  "explanation": "语境与句法解释",
  "corePoint": "一句中文核心观点",
  "keywords": [
    {
      "term": "English term",
      "translation": "中文释义"
    }
  ]
}
```

## 引用信息结果

```json
{
  "title": "Paper title",
  "authors": "Author One; Author Two",
  "year": "2026",
  "venue": "Journal or Conference",
  "doi": "10.xxxx/xxxxx",
  "tags": ["keyword 1", "keyword 2"],
  "citationText": "APA 7 citation",
  "confidence": 0.9,
  "rationale": "识别依据及待核对项"
}
```

缺失字段应返回空字符串或空数组，不要编造元数据。标准输出可以包含 JSON 代码围栏或少量前后文本，但只输出 JSON 最可靠。

## 最小适配器思路

兼容层通常只需完成三件事：读取标准输入、调用用户选定的 Agent、把 Agent 的最终 JSON 原样写到标准输出。PaperPrism 不要求特定编程语言、SDK、模型或服务商。

适配器应自行处理超时、登录和联网权限，并确保日志不包含访问令牌或论文敏感内容。
