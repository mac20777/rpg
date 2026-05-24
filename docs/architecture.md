# 项目结构说明

## 当前原则

- `scenes/` 放可复用场景，例如玩家、主游戏场景。
- `scripts/game/` 放局内流程协调模块，例如主循环、刷怪导演。
- `scripts/actors/` 放有场景节点的角色逻辑，例如玩家。
- `scripts/entities/` 放轻量运行时数据对象，例如子弹、经验球、僵尸状态。
- `scripts/enemies/` 放敌人配置、类型选择和行为规则。
- `scripts/weapons/` 放武器运行时、武器发射逻辑和武器通用工具。
- `scripts/upgrades/` 放升级池、升级选项生成和后续稀有度/前置条件规则。
- `scripts/relics/` 放遗物状态和遗物效果钩子。
- `scripts/events/` 放地图事件生成节奏，例如补给箱和守点事件。
- `scripts/economy/` 放局内经济状态和掉落策略，例如金币钱包、金币掉落预算。
- `scripts/merchants/` 放商人商品、商品锁定、购买记录和交易规则。
- `scripts/feedback/` 放音效、屏幕反馈等不改变玩法规则的反馈模块。
- `scripts/meta/` 放局外进度、解锁条件、存档读写。
- 后续新增系统时优先新建独立模块，再由 `scripts/game/game.gd` 调用，避免继续把全部逻辑塞进主脚本。

## 现有模块

### 主游戏场景

- 场景：`scenes/game/main.tscn`
- 脚本：`scripts/game/game.gd`
- 职责：
  - 维护局内状态：敌人、子弹、经验球、升级选择。
  - 调用玩家、刷怪导演、敌人行为、武器和 UI 更新。
  - 处理碰撞、击杀、经验拾取、升级界面和游戏结束。

### 玩家

- 场景：`scenes/actors/player.tscn`
- 脚本：`scripts/actors/player.gd`
- 职责：
  - 玩家移动、受伤、升级属性、瞄准方向。
  - 玩家自己的数值状态留在玩家脚本里，不放到主游戏脚本。

### 刷怪导演

- 脚本：`scripts/game/spawn_director.gd`
- 脚本：`scripts/game/elite_director.gd`
- 职责：
  - 控制刷怪预算、敌人数量上限、小波次、大波次。
  - 返回本帧应该生成的敌人类型请求。
  - 维护波次编号和清理节奏。
  - `EliteDirector` 独立控制精英怪的定时生成，避免精英节奏和普通刷怪预算混在一起。

### 敌人配置与行为

- 脚本：`scripts/enemies/enemy_catalog.gd`
- 职责：
  - 定义普通僵尸、冲刺者、爆炸者的基础数值。
  - 根据时间和波次偏置选择敌人类型。
  - 创建 `ZombieState`。
  - 更新特殊敌人行为，例如冲刺者间歇冲锋。

### 轻量实体状态

- `scripts/entities/zombie_state.gd`
- `scripts/entities/bullet_state.gd`
- `scripts/entities/xp_orb_state.gd`
- `scripts/entities/reward_chest_state.gd`
- `scripts/entities/supply_cache_state.gd`
- `scripts/entities/holdout_event_state.gd`
- `scripts/entities/visual_effect_state.gd`

职责：

- 只存运行时数据，不承载场景节点和复杂流程。
- 数量可能很多的对象先保持轻量，减少后期性能压力。
- 宝箱也保持为轻量状态对象，由主游戏场景绘制和拾取。
- 补给箱和守点事件也只保存位置、半径、时间、进度等状态。
- 命中、击杀、升级、爆炸等视觉反馈使用 `VisualEffectState`，由主游戏场景统一绘制，并设置数量上限避免后期堆积。

### 地图事件

- `scripts/events/map_event_director.gd`

职责：

- 控制补给箱和守点事件的生成节奏。
- 根据玩家血量调整补给类型权重。
- 不直接应用补给效果，具体效果由主游戏场景在拾取时调用。

### 经济系统

- `scripts/economy/gold_wallets.gd`
- `scripts/economy/gold_drop_policy.gd`

职责：

- `GoldWallets` 维护每名玩家的本局金币余额，提供发放、扣费、序列化和快照恢复。
- `GoldDropPolicy` 维护普通怪金币掉落概率、掉落预算和金币物体上限相关规则。
- `scripts/game/game.gd` 只负责在击杀、拾取、宝箱和守点完成时调用经济模块，不直接承载经济平衡规则。

### 流浪商人

- `scripts/entities/merchant_event_state.gd`
- `scripts/merchants/merchant_catalog.gd`
- `scripts/merchants/merchant_panel_view.gd`
- `scripts/merchants/merchant_shop_state.gd`

职责：

- `MerchantEventState` 只保存商人的位置、交易范围、剩余时间、唯一 ID 和商品种子。
- `MerchantCatalog` 定义商品、价格、购买条件和购买效果。
- `MerchantPanelView` 创建和刷新商人交易面板，并通过信号把购买请求交回主流程。
- `MerchantShopState` 维护按玩家锁定的商品列表、已购买记录和受击后的重开冷却。
- 主游戏脚本只负责商人事件生成、绘制、打开/关闭本地交易 UI 和网络购买请求转发。
- 商人 UI 不设置 `choosing_upgrade`，多人游戏中不会暂停全队。

### 武器系统

- `scripts/weapons/weapon_loadout.gd`
- `scripts/weapons/weapon_helpers.gd`
- `scripts/weapons/pistol_weapon.gd`
- `scripts/weapons/shotgun_weapon.gd`
- `scripts/weapons/knife_weapon.gd`
- `scripts/weapons/flame_weapon.gd`
- `scripts/weapons/lightning_weapon.gd`

职责：

- `WeaponLoadout` 维护玩家当前拥有的武器列表，处理获得武器和武器升级。
- `WeaponLoadout` 也维护武器进化定义，判断武器等级、被动等级、遗物前置是否满足。
- 单个武器脚本只负责自己的冷却、目标选择后的发射形态和升级描述。
- 单个武器脚本内部保存进化状态，进化后切换为该武器的最终发射形态。
- `WeaponHelpers` 提供最近敌人查询和子弹生成，避免每个武器重复通用代码。
- `scripts/game/game.gd` 只调用 `weapon_loadout.update()`，不直接写具体武器发射逻辑。
- 当前武器池包含手枪、霰弹、飞刀、火球、电弧。火球负责慢速高伤害和大体积弹体，电弧负责高速穿透线性清怪。

### 升级池

- `scripts/upgrades/upgrade_catalog.gd`
- `scripts/upgrades/upgrade_state.gd`

职责：

- `UpgradeCatalog` 合并被动、武器、遗物升级选项，并按稀有度、前置条件、最大等级生成局内三选一候选。
- `UpgradeState` 记录被动升级等级，防止已经满级的升级继续进入候选池。
- 武器进化选项由 `WeaponLoadout` 生成，再进入 `UpgradeCatalog` 的候选池。
- 宝箱奖励复用升级池，但使用更偏向优秀/稀有选项的抽取权重。
- 后续稀有度、前置条件、奖励品质、宝箱升级池应继续扩展这个模块，而不是回写到主游戏脚本。

### 遗物系统

- `scripts/relics/relic_collection.gd`

职责：

- 记录当前局已获得的遗物。
- 提供局内钩子：新子弹生成、子弹命中、经验拾取、爆炸者击杀。
- 遗物只改变规则，不直接接管主循环。

### 反馈系统

- `scripts/feedback/feedback_audio.gd`
- `scripts/feedback/visual_effect_pool.gd`

职责：

- 运行时生成短促反馈音效，不依赖外部音频素材。
- 维护一组 `AudioStreamPlayer` 复用池，避免每次反馈都创建节点。
- 提供播放冷却，限制射击、命中、拾取等高频事件的声音密度。
- 维护视觉特效列表、生命周期和数量上限。
- 主游戏脚本只保留反馈触发点和绘制入口，具体音色、音量、冷却、特效生命周期和数量上限在反馈模块内维护。

### 局外进度

- `scripts/meta/meta_progression.gd`

职责：

- 记录最佳生存时间、最佳击杀数和总局数。
- 根据成就解锁初始武器和角色。
- 保存玩家偏好的初始武器和角色到 `user://meta_progression.cfg`。
- 局外进度只解锁玩法选项，不提供永久数值堆叠。

## 后续扩展落点

- 升级系统：继续扩展 `scripts/upgrades/`，支持宝箱品质、定向奖励、武器进化前置。
- 道具体系：继续扩展 `scripts/relics/`，新增更多改变规则的遗物；补给类事件可以放到 `scripts/items/`。
- 精英和宝箱：继续扩展 `EnemyCatalog` 的精英类型，并把宝箱品质、掉落表、宝箱 UI 逐步独立出来。
- 地图事件：继续扩展 `scripts/events/`，加入祭坛、商人、临时挑战等路线目标。
- 反馈系统：继续扩展 `scripts/feedback/`，后续可拆分命中特效样式、屏幕震动和正式音频资源。
- 局外进度：继续扩展 `scripts/meta/`，加入新武器、新角色和更完整的开始界面。
