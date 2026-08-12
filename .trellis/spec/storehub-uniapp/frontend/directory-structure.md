# storehub-uniapp 目录结构

> UniApp + Vue3 + TypeScript。企业微信小程序 + H5 双端。wot-ui 组件库。API 三层架构。

```
src/
├── api/
│   ├── index.ts               # alova 实例初始化（baseURL/token/拦截器）
│   ├── apis/                   # 接口常量层
│   │   ├── chat.ts / home.ts / message.ts / user.ts / ...  # 按模块导出 API_PATH
│   │   └── contacts.ts         # 类型导出
│   ├── service/                # 服务层（业务逻辑包装）
│   │   └── *Service.ts         # async 函数，调用 alova.Post<ResponseData>(PATH).send()
│   └── utils/commom.ts         # token/平台检测/登录重定向
├── components/
│   ├── ai-robot.vue            # AI 聊天机器人
│   ├── MessagePopUp.vue / bulletin-popup.vue  # 弹窗组件
│   ├── layout/config-provider/ # 全局配置提供器（权限/主题/导航栏/水印）
│   ├── mTable/                 # 自定义表格组件
│   └── wot-ui/                 # wot-design-uni 组件（30+ 个，源码打包在项目中）
├── config/index.ts             # 全局常量（BASE_API_URL / env 变量）
├── enum/                       # 枚举常量
│   ├── errorCode.ts            # SUCCESS=0, INVALID_IDENTITY_CODE=-9999
│   ├── storage.ts              # BGMS_TOKEN / CLIENT_PLATFORM 等存储键
│   └── role.ts / platform.ts / ...
├── hooks/                      # 组合式函数
│   ├── use-uni-app.ts          # 生命周期包装（注入登录守卫）
│   ├── use-user-role.ts        # Pinia 用户角色 store 包装
│   └── use-calendar-weeks.ts / use-message.ts / ...
├── interfaces/                 # 共享类型（user.ts / tasks.ts）
├── pages-*/                    # 页面模块（按功能命名）
│   ├── pages-home/             # 首页仪表盘（多角色）
│   ├── pages-message/          # 消息中心
│   ├── pages-myInfo/           # "我的"
│   └── pages-task/             # 任务管理
├── store/
│   ├── index.ts                # createPinia() + 自定义插件
│   └── modules/                # Pinia Store 模块
│       ├── userInfoStore.ts    # 主 Store（登录/用户/角色/岗位）
│       └── homeStore.ts / subAppStore.ts / ...
├── theme-chalk/                # 全局 SCSS 主题
│   ├── var.scss                # CSS 自定义属性（主题色 #00a34f）
│   └── reset.scss              # 全局 Reset + 条件样式
├── utils/                      # 工具函数（微信/登录/地图/格式化）
│   ├── wx/                     # 微信专用工具
│   └── login/LoginManager.ts   # 登录管理器（队列 + 单例）
├── App.vue                     # 根组件（onLaunch/字体/神策/更新管理）
└── main.ts                     # createSSRApp().use(pinia).use(router)
```

**API 三层调用链**:
```
api/apis/chat.ts → 导出 API_CHAT_MESSAGE = '/chat/postMessage'
api/service/chatService.ts → export async sendChatMessage() { alova.Post(API_CHAT_MESSAGE).send() }
组件 ai-robot.vue → import sendChatMessage → await sendChatMessage()
```
