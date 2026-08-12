import Foundation

extension ExerciseLibraryCatalog {
    static let extendedItems: [ExerciseLibraryItem] = [
        e("march", "原地踏步", ["原地走"], .warmup, "低冲击提高心率。", "站直并放松肩部|交替抬脚并自然摆臂|保持均匀呼吸", "身体后仰|脚步过重", .countdown, 60, 15, "无", ["全身"]),
        e("shoulder-roll", "肩部绕环", ["肩绕环"], .warmup, "活动肩胛和肩颈。", "双臂自然下垂|肩膀向上后下缓慢画圈|换方向重复", "速度过快|耸肩憋气", .repetitions, nil, 10, "无", ["肩部"]),
        e("wrist-circle", "手腕绕环", ["腕关节绕环"], .warmup, "训练前活动手腕。", "双手在胸前放松|缓慢向两个方向转动|保持前臂稳定", "强压关节末端|带痛旋转", .countdown, 30, 0, "无", ["前臂"]),
        e("hip-circle", "髋关节绕环", ["髋绕环"], .warmup, "活动髋部并唤醒下肢。", "双脚稳定站立|骨盆缓慢画圈|换方向重复", "上身大幅摆动|动作过快", .countdown, 30, 10, "无", ["髋部"]),
        e("ankle-circle", "踝关节绕环", ["脚踝绕环"], .warmup, "活动脚踝。", "扶稳并抬起一脚|脚尖缓慢画圈|换脚和方向", "用膝盖代偿|带痛强转", .countdown, 30, 0, "无", ["踝部"]),
        e("leg-swing-front", "前后摆腿", ["腿前后摆动"], .warmup, "动态活动髋屈伸。", "单手扶稳|一腿前后控制摆动|躯干保持稳定", "追求过大幅度|腰部摇晃", .repetitions, nil, 10, "无", ["髋部", "腿部"]),
        e("leg-swing-side", "侧向摆腿", ["左右摆腿"], .warmup, "动态活动髋内收外展。", "面对支撑物站稳|一腿在身体前方左右摆动|换侧重复", "骨盆跟随旋转|用惯性甩腿", .repetitions, nil, 10, "无", ["髋部"]),
        e("bodyweight-good-morning", "徒手早安式", ["髋铰链练习"], .warmup, "学习髋铰链动作。", "双脚与髋同宽|髋部后移并保持背部中立|臀部发力站起", "弓背|动作变成深蹲", .repetitions, nil, 20, "无", ["臀部", "腘绳肌"]),
        e("world-greatest-stretch", "世界最佳拉伸", ["弓步转体拉伸"], .mobility, "综合活动髋部、胸椎和腿后侧。", "迈入长弓步并撑地|同侧手向上旋转|控制返回后换侧", "前膝内扣|旋转来自腰部", .repetitions, nil, 15, "无", ["髋部", "胸椎"]),
        e("wall-ankle-mobility", "靠墙踝背屈", ["膝碰墙"], .mobility, "改善踝背屈活动度。", "脚掌完全踩地面对墙|膝盖朝脚尖方向靠墙|逐步调整脚与墙距离", "脚跟抬起|膝盖内扣", .repetitions, nil, 10, "墙", ["踝部"]),

        e("sumo-squat", "相扑深蹲", ["宽距深蹲"], .strength, "宽站距下肢力量动作。", "双脚宽于肩并略外旋|髋膝同步下沉|脚掌推地站起", "膝盖内扣|骨盆失控前倾", .repetitions, nil, 60, "无", ["臀部", "股四头肌", "内收肌"]),
        e("wall-sit", "靠墙静蹲", ["墙蹲"], .strength, "下肢等长耐力训练。", "背部贴墙并向下滑|膝盖朝脚尖方向|均匀呼吸并保持", "膝盖内扣|憋气", .countdown, 30, 45, "墙", ["股四头肌", "臀部"]),
        e("forward-lunge", "前跨弓步", ["正向弓步"], .strength, "训练单腿力量和平衡。", "向前迈出足够步幅|双膝屈曲垂直下降|前脚推地返回", "前膝内扣|步幅过小", .repetitions, nil, 60, "无", ["臀部", "股四头肌"]),
        e("lateral-lunge", "侧弓步", ["侧向弓步"], .strength, "训练侧向移动和髋部力量。", "向侧方迈一大步|髋部后移屈曲支撑腿|推地回到中间", "支撑膝内扣|另一脚离地", .repetitions, nil, 60, "无", ["臀部", "内收肌"]),
        e("split-squat", "原地分腿蹲", ["静态弓步蹲"], .strength, "稳定的单腿力量入门动作。", "前后分腿站稳|身体垂直下降|前脚推地起身", "站距过窄|前膝内扣", .repetitions, nil, 60, "无", ["臀部", "股四头肌"]),
        e("bulgarian-split-squat", "保加利亚分腿蹲", ["后脚抬高分腿蹲"], .strength, "进阶单腿力量动作。", "后脚放在稳固支撑面|前脚保持全脚掌受力|控制下降再站起", "支撑物不稳|前膝内扣", .repetitions, nil, 75, "长凳", ["臀部", "股四头肌"]),
        e("single-leg-glute-bridge", "单腿臀桥", ["单腿桥"], .strength, "提高臀桥的单侧负荷。", "仰卧屈曲支撑腿|另一腿抬起并稳定骨盆|臀部发力抬髋", "骨盆旋转|腰部代偿", .repetitions, nil, 45, "无", ["臀部", "腘绳肌"]),
        e("knee-push-up", "跪姿俯卧撑", ["膝盖俯卧撑"], .strength, "介于靠墙和标准俯卧撑之间的回归动作。", "膝盖着地并保持头到膝成线|胸口整体下降|推地返回", "髋部折叠|手肘完全外展", .repetitions, nil, 60, "垫子", ["胸部", "肱三头肌"]),
        e("incline-push-up", "上斜俯卧撑", ["高位俯卧撑"], .strength, "用高支撑降低俯卧撑难度。", "双手撑稳固高台|身体保持直线|胸口靠近支撑面后推回", "支撑物滑动|塌腰", .repetitions, nil, 60, "长凳", ["胸部", "肱三头肌"]),
        e("bench-dip", "凳上臂屈伸", ["凳上反屈伸"], .strength, "训练肱三头肌的自重动作。", "双手撑稳凳边|身体靠近凳面下降|手臂发力推起", "肩部过度前移|下降过深", .repetitions, nil, 60, "长凳", ["肱三头肌"]),

        e("high-plank", "高位平板支撑", ["直臂平板"], .core, "训练核心和肩部支撑。", "双手位于肩下|收紧腹部和臀部|全身保持直线", "塌腰|肩胛失控", .countdown, 30, 30, "无", ["核心", "肩部"]),
        e("side-plank", "侧平板支撑", ["侧桥"], .core, "训练侧向核心稳定。", "手肘位于肩下|双腿叠放或前后支撑|抬髋保持身体直线", "肩部塌陷|骨盆旋转", .countdown, 30, 30, "无", ["腹斜肌", "臀中肌"]),
        e("crunch", "仰卧卷腹", ["卷腹"], .core, "训练腹部躯干屈曲控制。", "仰卧屈膝并收紧腹部|肩胛缓慢离地|控制回落", "用手拉头|靠惯性起身", .repetitions, nil, 30, "垫子", ["腹直肌"]),
        e("reverse-crunch", "反向卷腹", ["屈膝反向卷腹"], .core, "训练骨盆后倾和下腹控制。", "仰卧抬腿屈膝|腹部发力卷起骨盆|缓慢放回", "甩腿借力|腰部突然砸地", .repetitions, nil, 30, "垫子", ["腹直肌"]),
        e("lying-leg-raise", "仰卧抬腿", ["直腿抬腿"], .core, "训练核心抗伸展和髋屈。", "仰卧并稳定腰背|双腿控制抬起|在腰背不拱起前下降", "下降过低导致拱腰|动作过快", .repetitions, nil, 45, "垫子", ["核心", "髋屈肌"]),
        e("russian-twist", "俄罗斯转体", ["坐姿转体"], .core, "训练躯干旋转控制。", "坐姿屈膝并保持胸口打开|腹部收紧后左右旋转|动作来自胸椎", "含胸|只摆动手臂", .repetitions, nil, 30, "无", ["腹斜肌"]),
        e("bicycle-crunch", "自行车卷腹", ["空中自行车"], .core, "结合躯干旋转和交替伸腿。", "仰卧并抬起肩胛|对侧肩和膝相互靠近|缓慢交替换侧", "拉扯颈部|速度过快", .repetitions, nil, 30, "垫子", ["腹直肌", "腹斜肌"]),
        e("hollow-hold", "Hollow Hold", ["中空支撑", "船式支撑"], .core, "进阶核心抗伸展等长动作。", "仰卧并让腰背贴稳|抬起肩胛和双腿|保持呼吸和躯干张力", "腰部拱起|憋气", .countdown, 20, 40, "垫子", ["核心"]),
        e("bear-plank", "熊爬支撑", ["Bear Plank"], .core, "四足悬膝核心稳定。", "四足跪姿手膝对齐|膝盖轻抬离地|保持背部平稳", "臀部抬高|身体摇晃", .countdown, 20, 30, "垫子", ["核心", "肩部"]),

        e("db-goblet-squat", "哑铃杯式深蹲", ["杯式深蹲"], .dumbbell, "前置负重深蹲。", "双手在胸前托住哑铃|髋膝同步下沉|脚掌推地站起", "哑铃远离身体|膝盖内扣", .repetitions, nil, 75, "哑铃", ["股四头肌", "臀部"]),
        e("db-rdl", "哑铃罗马尼亚硬拉", ["哑铃直腿硬拉"], .dumbbell, "训练臀腿后侧髋铰链。", "哑铃贴近双腿|髋部后移并保持背部中立|臀部发力站起", "弓背|哑铃离身体过远", .repetitions, nil, 75, "哑铃", ["臀部", "腘绳肌"]),
        e("db-lunge", "哑铃弓步", ["负重弓步"], .dumbbell, "哑铃负重单腿力量动作。", "双手稳定持铃|迈步后垂直下降|前脚推地返回", "身体摇晃|前膝内扣", .repetitions, nil, 75, "哑铃", ["臀部", "股四头肌"]),
        e("db-step-up", "哑铃台阶蹲", ["哑铃登阶"], .dumbbell, "单腿登阶力量动作。", "选择稳固适当高度台阶|整只脚踩上台面|支撑腿发力站上后控制下降", "后腿蹬地借力|台面不稳", .repetitions, nil, 75, "哑铃、台阶", ["臀部", "股四头肌"]),
        e("db-bench-press", "哑铃卧推", ["平板哑铃卧推"], .dumbbell, "训练胸部和推举力量。", "仰卧并稳定肩胛|哑铃控制下降到胸部两侧|向上推起但不碰撞", "肩膀耸起|手腕折叠", .repetitions, nil, 90, "哑铃、长凳", ["胸部", "肱三头肌"]),
        e("db-incline-press", "上斜哑铃卧推", ["哑铃上斜卧推"], .dumbbell, "偏重上胸的推举动作。", "调整长凳至适中角度|肩胛稳定并控制下放|沿自然轨迹推起", "凳面角度过高|手腕折叠", .repetitions, nil, 90, "哑铃、长凳", ["胸部", "肩部"]),
        e("db-fly", "哑铃飞鸟", ["平板哑铃飞鸟"], .dumbbell, "胸部水平内收动作。", "仰卧并微屈手肘|沿弧线控制打开双臂|胸部发力合回", "重量过大|下降过深", .repetitions, nil, 75, "哑铃、长凳", ["胸部"]),
        e("db-one-arm-row", "单臂哑铃划船", ["单手哑铃划船"], .dumbbell, "训练背部单侧拉力。", "一手一膝稳定支撑|背部保持中立|手肘向髋部方向拉动", "躯干旋转|耸肩", .repetitions, nil, 75, "哑铃、长凳", ["背阔肌", "上背"]),
        e("db-bent-row", "俯身哑铃划船", ["双臂哑铃划船"], .dumbbell, "双侧背部水平拉。", "髋铰链进入俯身姿势|保持躯干稳定|双肘向后拉再控制下降", "弓背|借身体弹动", .repetitions, nil, 75, "哑铃", ["背阔肌", "上背"]),
        e("db-shoulder-press", "哑铃肩推", ["哑铃推举"], .dumbbell, "肩部垂直推举。", "坐姿或站姿稳定核心|哑铃从肩侧向上推|控制回到肩侧", "过度挺腰|哑铃碰撞", .repetitions, nil, 90, "哑铃", ["肩部", "肱三头肌"]),
        e("db-lateral-raise", "哑铃侧平举", ["侧平举"], .dumbbell, "训练三角肌中束。", "双手持轻重量并微屈肘|向侧方抬至舒适高度|控制下降", "耸肩|甩动身体", .repetitions, nil, 60, "哑铃", ["肩部"]),
        e("db-rear-fly", "俯身反向飞鸟", ["哑铃反向飞鸟"], .dumbbell, "训练肩后束和上背。", "髋铰链俯身并保持背部中立|双臂向侧后方打开|控制回落", "耸肩|腰部摆动", .repetitions, nil, 60, "哑铃", ["肩后束", "上背"]),
        e("db-curl", "哑铃弯举", ["二头弯举"], .dumbbell, "训练肱二头肌。", "手肘贴近身体|屈肘举起哑铃|控制下降至手臂伸展", "身体后仰借力|手肘前移", .repetitions, nil, 60, "哑铃", ["肱二头肌"]),
        e("hammer-curl", "锤式弯举", ["锤式哑铃弯举"], .dumbbell, "中立握法手臂屈曲。", "掌心相对持铃|保持手肘稳定完成弯举|控制下降", "耸肩|身体摆动", .repetitions, nil, 60, "哑铃", ["肱肌", "肱二头肌"]),
        e("db-overhead-extension", "哑铃过顶臂屈伸", ["哑铃颈后臂屈伸"], .dumbbell, "训练肱三头肌。", "双手稳定托铃举过头顶|保持上臂相对固定|屈伸手肘控制重量", "过度挺腰|手肘大幅外张", .repetitions, nil, 60, "哑铃", ["肱三头肌"]),
        e("kb-deadlift", "壶铃硬拉", ["壶铃提拉"], .dumbbell, "壶铃髋铰链入门动作。", "壶铃放在双脚之间|髋部后移握住壶铃|脚掌推地并伸髋站起", "弓背|用手臂提拉", .repetitions, nil, 75, "壶铃", ["臀部", "腘绳肌"]),
        e("kb-swing", "壶铃摆动", ["俄式壶铃摆动"], .dumbbell, "爆发式髋铰链动作。", "壶铃从双腿间后摆|快速伸髋推动壶铃前摆|保持手臂放松并控制回摆", "用手臂抬铃|动作变成深蹲", .repetitions, nil, 90, "壶铃", ["臀部", "腘绳肌"]),

        e("barbell-back-squat", "杠铃后蹲", ["杠铃深蹲"], .barbell, "杠铃下肢复合动作。", "杠铃稳定放在上背|脚掌稳定并主动收紧躯干|控制下蹲后站起", "重量超出控制|膝盖内扣", .repetitions, nil, 120, "杠铃、深蹲架", ["股四头肌", "臀部"], "建议在保护架或有人保护时练习"),
        e("barbell-front-squat", "杠铃前蹲", ["前蹲"], .barbell, "前置杠铃深蹲。", "建立稳定前架姿势|保持肘部抬起和躯干直立|控制下蹲并站起", "杠铃压在手腕|肘部下落", .repetitions, nil, 120, "杠铃、深蹲架", ["股四头肌", "核心"], "先掌握空杆前架姿势"),
        e("barbell-deadlift", "传统硬拉", ["杠铃硬拉"], .barbell, "地面起拉的髋主导复合动作。", "杠铃靠近小腿中部|收紧躯干并让背部保持中立|脚掌推地将杠铃贴身拉起", "弓背猛拉|杠铃离身体过远", .repetitions, nil, 150, "杠铃", ["臀部", "腘绳肌", "背部"], "初学者应使用可控重量学习动作"),
        e("barbell-rdl", "杠铃罗马尼亚硬拉", ["杠铃直腿硬拉"], .barbell, "从站姿开始的髋铰链训练。", "杠铃贴近大腿|髋部后移并保持背部中立|臀部发力回到站姿", "杠铃前飘|膝盖过度屈曲", .repetitions, nil, 120, "杠铃", ["臀部", "腘绳肌"]),
        e("barbell-hip-thrust", "杠铃臀推", ["负重臀推"], .barbell, "高负荷臀部伸展动作。", "肩胛靠稳长凳并固定杠铃垫|脚掌踩稳后抬髋|顶部保持骨盆中立", "腰部过伸|长凳或杠铃不稳", .repetitions, nil, 120, "杠铃、长凳、护垫", ["臀部"]),
        e("barbell-bench-press", "杠铃卧推", ["平板杠铃卧推"], .barbell, "胸部水平推举复合动作。", "肩胛稳定并握紧杠铃|控制杠铃下降到胸部|推回起始位置", "无保护独自冲击大重量|手腕过度折叠", .repetitions, nil, 150, "杠铃、卧推架", ["胸部", "肱三头肌"], "使用安全杆或保护者"),
        e("barbell-overhead-press", "站姿杠铃推举", ["杠铃肩推"], .barbell, "站姿垂直推举。", "杠铃置于肩前并收紧核心|头部让开杠铃垂直路径|推过头顶后控制下降", "过度挺腰|杠铃绕行过远", .repetitions, nil, 120, "杠铃、深蹲架", ["肩部", "肱三头肌"]),
        e("barbell-row", "杠铃俯身划船", ["杠铃划船"], .barbell, "背部水平拉复合动作。", "髋铰链进入稳定俯身|杠铃向腹部方向拉动|控制下降且躯干不变", "弓背|靠身体弹动", .repetitions, nil, 120, "杠铃", ["背阔肌", "上背"]),
        e("barbell-curl", "杠铃弯举", ["直杆弯举"], .barbell, "双侧肱二头肌训练。", "站稳并保持手肘靠近身体|屈肘举起杠铃|控制下降", "身体后仰|手肘前移", .repetitions, nil, 75, "杠铃", ["肱二头肌"]),
        e("barbell-good-morning", "杠铃早安式", ["负重早安式"], .barbell, "进阶髋铰链动作。", "杠铃稳定放在上背|髋部后移保持脊柱中立|臀部发力站起", "重量过大|弓背", .repetitions, nil, 120, "杠铃、深蹲架", ["臀部", "腘绳肌"], "先熟练徒手髋铰链"),

        e("lat-pulldown", "高位下拉", ["正握高位下拉"], .machine, "训练背阔肌的垂直拉。", "调整腿垫并坐稳|肩胛下沉后将握杆拉向上胸|控制回到手臂伸展", "身体大幅后仰|拉到颈后", .repetitions, nil, 75, "高位下拉机", ["背阔肌"]),
        e("seated-cable-row", "坐姿绳索划船", ["坐姿划船"], .machine, "训练背部水平拉。", "双脚踩稳并保持躯干直立|手肘向后拉至身体两侧|控制伸臂", "腰部反复摆动|耸肩", .repetitions, nil, 75, "绳索器械", ["背阔肌", "上背"]),
        e("face-pull", "面拉", ["绳索面拉"], .machine, "训练肩后束和肩胛控制。", "绳索设置在面部高度|拉向眼睛两侧并外旋手臂|控制返回", "耸肩|腰部后仰", .repetitions, nil, 60, "绳索器械", ["肩后束", "上背"]),
        e("cable-chest-fly", "绳索夹胸", ["龙门架夹胸"], .machine, "持续张力的胸部内收动作。", "双手握把并前后站稳|微屈肘将双臂合向胸前|控制打开", "肩部前顶|重量过大", .repetitions, nil, 60, "绳索器械", ["胸部"]),
        e("cable-lateral-raise", "绳索侧平举", ["单臂绳索侧平举"], .machine, "绳索阻力的肩部外展。", "低位握住绳索把手|保持肩部下沉向侧方抬臂|控制下降", "耸肩|身体倾斜借力", .repetitions, nil, 60, "绳索器械", ["肩部"]),
        e("cable-curl", "绳索弯举", ["拉力器弯举"], .machine, "持续张力的手臂屈曲。", "低位连接握把并站稳|固定手肘完成弯举|控制伸展", "身体摇摆|手肘前移", .repetitions, nil, 60, "绳索器械", ["肱二头肌"]),
        e("triceps-pushdown", "绳索下压", ["肱三头肌下压"], .machine, "训练肱三头肌。", "手肘贴近身体握住附件|伸直手肘向下压|控制返回", "肩膀前后摆动|手肘离开身体", .repetitions, nil, 60, "绳索器械", ["肱三头肌"]),
        e("leg-press", "腿举", ["坐姿腿推"], .machine, "器械下肢复合推蹬。", "调整座椅并让脚掌踩稳踏板|解锁后控制屈膝下降|脚掌推回但不锁死膝盖", "腰臀离开靠垫|膝盖内扣", .repetitions, nil, 90, "腿举机", ["股四头肌", "臀部"]),
        e("leg-extension", "腿屈伸", ["坐姿腿屈伸"], .machine, "股四头肌器械训练。", "调整转轴对齐膝关节|伸膝抬起滚垫|控制下降", "用惯性甩起|膝部不适仍加重", .repetitions, nil, 60, "腿屈伸机", ["股四头肌"]),
        e("lying-leg-curl", "俯卧腿弯举", ["俯卧腿屈曲"], .machine, "腘绳肌器械训练。", "膝关节对齐器械转轴|屈膝拉动滚垫|控制伸展", "髋部离开垫面|快速回落", .repetitions, nil, 60, "腿弯举机", ["腘绳肌"]),
        e("machine-chest-press", "器械推胸", ["坐姿推胸"], .machine, "稳定轨迹的胸部推举。", "调整座椅让把手与胸部对齐|肩胛靠稳后推开把手|控制返回", "肩膀前顶|手肘锁死", .repetitions, nil, 75, "推胸机", ["胸部", "肱三头肌"]),
        e("pec-deck", "蝴蝶机夹胸", ["器械夹胸"], .machine, "器械胸部内收动作。", "调整座椅和手臂垫位置|胸部发力合拢|控制打开至舒适范围", "肩部前移|打开过深", .repetitions, nil, 60, "蝴蝶机", ["胸部"]),
        e("machine-shoulder-press", "器械肩推", ["坐姿器械推举"], .machine, "固定轨迹肩部推举。", "调整座椅让把手位于肩侧|保持核心稳定向上推|控制下降", "过度挺腰|肩部疼痛仍继续", .repetitions, nil, 75, "肩推机", ["肩部", "肱三头肌"]),
        e("assisted-pull-up", "辅助引体向上", ["器械辅助引体"], .machine, "使用配重辅助完成垂直拉。", "设置合适辅助重量并稳步上机|肩胛下沉后拉起身体|控制下降", "快速弹动|下机时配重失控", .repetitions, nil, 90, "辅助引体机", ["背阔肌", "肱二头肌"]),

        e("burpee", "波比跳", ["Burpee"], .cardio, "高强度全身有氧动作。", "下蹲双手撑地|双脚后撤到支撑再收回|站起或轻跳完成", "塌腰|疲劳后落地失控", .repetitions, nil, 60, "无", ["全身"], "初学者可取消跳跃并逐步加速"),
        e("fast-feet", "原地小碎步", ["快速脚步"], .cardio, "提高脚步频率的间歇动作。", "微屈膝保持低重心|双脚快速交替小步触地|保持上身稳定", "脚步过大|膝盖僵直", .countdown, 30, 30, "无", ["下肢", "心肺"]),
        e("skater-jump", "滑冰跳", ["Skater Jump"], .cardio, "侧向跳跃和稳定训练。", "向侧方跳到单脚|髋膝屈曲吸收落地|稳定后跳向另一侧", "膝盖内扣|落地过重", .countdown, 30, 45, "无", ["臀部", "下肢"], "先用不跳跃的侧向跨步练习"),
        e("squat-jump", "深蹲跳", ["跳跃深蹲"], .cardio, "下肢爆发和心肺动作。", "下蹲至可控深度|脚掌发力向上跳|轻柔落地并重新稳定", "膝盖内扣|连续落地失控", .repetitions, nil, 60, "无", ["下肢", "心肺"], "膝踝不适时改为徒手深蹲"),
        e("shadow-rope", "跳绳", ["有绳跳绳"], .cardio, "使用跳绳的节奏性有氧。", "调整绳长并保持身体直立|手腕小幅转绳|前脚掌轻柔落地", "用手臂大幅甩绳|跳得过高", .countdown, 60, 45, "跳绳", ["小腿", "心肺"]),

        e("doorway-chest-stretch", "门框胸肌拉伸", ["胸肌拉伸"], .cooldown, "拉伸胸部前侧。", "前臂放在稳固门框|身体缓慢向前移动|保持肩部下沉", "强压肩关节|腰部前顶", .countdown, 30, 10, "门框", ["胸部"]),
        e("lat-stretch", "背阔肌拉伸", ["背部侧向拉伸"], .cooldown, "拉伸背阔肌和躯干侧面。", "双手扶稳固定物|髋部后移并降低胸口|向一侧偏移增强对侧拉伸", "弓背强压|肩部疼痛", .countdown, 30, 10, "固定支撑", ["背阔肌"]),
        e("rear-shoulder-stretch", "肩后束拉伸", ["横臂肩部拉伸"], .cooldown, "拉伸肩部后侧。", "一臂横过胸前|另一臂轻轻固定|保持肩部下沉", "拉扯手肘过猛|耸肩", .countdown, 30, 10, "无", ["肩后束"]),
        e("triceps-stretch", "肱三头肌拉伸", ["过顶手臂拉伸"], .cooldown, "拉伸上臂后侧。", "一臂举过头顶并屈肘|另一手轻扶手肘|保持躯干直立", "用力压颈部|过度挺腰", .countdown, 30, 10, "无", ["肱三头肌"]),
        e("hip-flexor-stretch", "跪姿髋屈肌拉伸", ["髋前侧拉伸"], .cooldown, "拉伸髋部前侧。", "进入半跪姿并垫好膝盖|轻收骨盆后向前移动|保持躯干直立", "腰部过伸|前膝内扣", .countdown, 30, 10, "垫子", ["髋屈肌"]),
        e("butterfly-stretch", "蝴蝶式拉伸", ["坐姿内收肌拉伸"], .cooldown, "拉伸大腿内侧。", "坐姿让双脚掌相对|保持背部自然直立|膝盖自然向两侧放松", "用手强压膝盖|弓背前趴", .countdown, 30, 10, "垫子", ["内收肌"]),
        e("quad-stretch", "站姿股四头肌拉伸", ["大腿前侧拉伸"], .cooldown, "拉伸大腿前侧。", "扶稳后屈膝握住脚踝|双膝靠近并轻收骨盆|保持躯干直立", "膝盖向外散开|腰部过伸", .countdown, 30, 10, "无", ["股四头肌"]),
        e("calf-wall-stretch", "靠墙小腿拉伸", ["小腿靠墙拉伸"], .cooldown, "拉伸小腿后侧。", "双手扶墙并前后分腿|后脚跟踩地|身体缓慢前移", "后脚外翻|弹振拉伸", .countdown, 30, 10, "墙", ["小腿"]),
        e("step-jack", "低冲击开合步", ["无跳开合跳"], .cardio, "开合跳的低冲击替代动作。", "自然站立并微屈膝|单脚向侧方迈出同时双臂上举|回到中间后换侧", "膝盖僵直|身体左右失控", .countdown, 45, 20, "无", ["全身", "心肺"]),
        e("heel-kick", "后踢腿跑", ["后踢腿", "踢臀跑"], .cardio, "动态热身和跑步技术动作。", "保持躯干直立|交替屈膝让脚跟靠近臀部|手臂自然摆动", "身体前倾过多|落地过重", .countdown, 30, 20, "无", ["腘绳肌", "心肺"]),
        e("toe-touch", "交替触脚尖", ["站姿触脚尖"], .warmup, "动态活动腿后侧和躯干。", "双脚适度分开站立|一手触碰对侧脚尖|回到站姿后换侧", "弓背猛压|膝盖锁死", .repetitions, nil, 10, "无", ["腘绳肌", "躯干"]),
        e("scapular-push-up", "肩胛俯卧撑", ["肩胛撑"], .mobility, "练习肩胛前伸和后缩控制。", "进入高位平板并保持手肘伸直|胸口轻微下沉让肩胛靠近|推地使肩胛分开", "屈伸手肘|塌腰", .repetitions, nil, 20, "无", ["前锯肌", "肩胛稳定肌"]),
        e("prone-y-raise", "俯卧Y字上举", ["俯卧Y举"], .mobility, "训练下斜方肌和肩胛控制。", "俯卧并将手臂摆成Y字|拇指朝上轻抬手臂|保持颈部放松后控制放下", "耸肩|过度抬头", .repetitions, nil, 20, "垫子", ["下斜方肌", "肩部"]),
        e("clamshell", "蚌式开合", ["侧卧蚌式"], .strength, "训练臀中肌和髋外旋控制。", "侧卧屈髋屈膝并叠放双脚|保持骨盆稳定打开上侧膝盖|控制合回", "骨盆向后翻|双脚分开", .repetitions, nil, 30, "垫子", ["臀中肌"]),
        e("fire-hydrant", "跪姿侧抬腿", ["消防栓式"], .strength, "四足姿势训练臀中肌。", "四足跪姿收紧核心|一侧膝盖向侧方抬起|保持骨盆稳定后控制放下", "躯干侧移|腰部旋转", .repetitions, nil, 30, "垫子", ["臀中肌"]),
        e("donkey-kick", "跪姿后抬腿", ["驴踢", "后踢腿"], .strength, "四足姿势训练臀部伸展。", "四足跪姿并保持骨盆稳定|屈膝向后上方抬腿|臀部发力后控制返回", "腰部过伸|骨盆旋转", .repetitions, nil, 30, "垫子", ["臀大肌"]),
        e("pallof-press", "Pallof Press", ["帕洛夫推", "抗旋转推"], .machine, "训练核心抗旋转。", "绳索设置在胸口高度并侧对器械|双手将握把推离胸口|抵抗旋转后控制收回", "身体被绳索拉转|耸肩", .repetitions, nil, 45, "绳索器械", ["核心"]),
        e("cable-woodchop", "绳索伐木", ["绳索转体下拉"], .machine, "训练躯干旋转和髋肩协调。", "侧对高位绳索站稳|双手沿斜线拉向对侧髋部|控制返回并保持脚掌稳定", "只用手臂拉|腰部突然扭转", .repetitions, nil, 60, "绳索器械", ["腹斜肌", "核心"]),
        e("farmers-carry", "农夫行走", ["农夫走"], .dumbbell, "训练握力、核心和负重行走。", "双手稳定持重并站直|保持躯干和骨盆稳定向前走|在安全位置控制放下", "身体左右倾斜|耸肩", .stopwatch, nil, 60, "哑铃或壶铃", ["握力", "核心", "全身"]),
        e("db-front-raise", "哑铃前平举", ["前平举"], .dumbbell, "训练三角肌前束。", "双手持轻重量并保持核心稳定|向前抬臂至舒适高度|控制下降", "身体后仰借力|耸肩", .repetitions, nil, 60, "哑铃", ["肩部"]),
        e("barbell-shrug", "杠铃耸肩", ["负重耸肩"], .barbell, "训练上斜方肌。", "双手持杠铃自然站立|肩膀垂直向上抬起|短暂停留后控制下降", "转动肩关节|屈肘提拉", .repetitions, nil, 60, "杠铃", ["上斜方肌"]),
        e("hack-squat", "哈克深蹲", ["哈克机深蹲"], .machine, "固定轨迹下肢深蹲。", "调整肩垫和脚位后解锁|背部贴稳靠垫控制下降|脚掌推踏板站起", "膝盖内扣|腰臀离开靠垫", .repetitions, nil, 90, "哈克深蹲机", ["股四头肌", "臀部"]),
        e("seated-leg-curl", "坐姿腿弯举", ["坐姿腿屈曲"], .machine, "坐姿训练腘绳肌。", "调整器械转轴对齐膝关节|固定大腿后屈膝|控制回到伸展", "身体离开靠垫|快速回弹", .repetitions, nil, 60, "坐姿腿弯举机", ["腘绳肌"]),
        e("baduanjin", "八段锦", ["健身气功八段锦", "国体版八段锦"], .traditional, "由八组动作组成的低冲击传统健身功法，适合按完整口令跟练。", "选择通风且地面平整的位置自然站立|先观看动作方向，再跟随口令连续完成八式|动作保持舒缓连贯，不追求极限幅度|结束后原地站立片刻，让呼吸自然恢复", "为了跟上口令而动作过快|憋气完成动作|膝关节内扣或强压关节末端", .countdown, 720, 60, "无", ["全身", "肩背", "下肢"], difficulty: "入门", breathing: ["以自然呼吸为主，不熟悉时不要强行配合呼吸节奏", "呼吸困难或头晕时立即恢复自然呼吸"], contraindications: ["急性关节损伤、明显眩晕或医生要求限制活动时暂缓练习"], videoAuthor: "蔡树欣教传统养生功", videoDurationSeconds: 708),
        e("taiji-eight-methods-five-steps", "太极八法五步", ["八法五步", "太极操"], .traditional, "国家体育总局推广的太极入门套路，组合基本手法、步法和平衡移动。", "先学习起势和重心转移再完整跟练|移动时保持躯干自然竖直，脚掌稳定落地|手臂随身体重心协调移动|按自身空间缩小步幅也可以", "只摆手臂而躯干与重心不动|膝盖内扣|转身时脚掌固定导致膝部扭转", .countdown, 190, 60, "无", ["全身", "下肢", "核心"], difficulty: "入门", breathing: ["初学阶段保持自然、均匀呼吸", "动作熟悉后再尝试呼吸与开合配合"], contraindications: ["平衡能力较弱时应靠近稳定支撑物练习", "膝踝疼痛时缩小步幅或停止"], videoAuthor: "功夫熊猫大力士", videoDurationSeconds: 189),
        e("simplified-taiji-24", "24式简化太极拳", ["二十四式太极拳", "简化太极拳"], .traditional, "完整的 24 式简化太极拳跟练项目，适合已经熟悉基本步法后使用。", "先确保周围有足够转身和迈步空间|跟随背向示范按口令完成整套动作|重心转换保持缓慢可控|不熟悉的动作可以暂停后分段学习", "勉强追赶完整套路|转体时膝盖与脚尖方向不一致|耸肩和屏息", .countdown, 345, 90, "无", ["全身", "下肢", "核心"], difficulty: "进阶入门", breathing: ["完整跟练时保持自然呼吸，不因记动作而憋气"], contraindications: ["首次练习建议先掌握八法五步或基本重心转移", "平衡不稳时不要独自在湿滑地面练习"], videoAuthor: "一位健身看客而已", videoDurationSeconds: 345),
        e("wuqinxi", "五禽戏", ["健身气功五禽戏", "华佗五禽戏"], .traditional, "模仿虎、鹿、熊、猿、鸟特点的完整低冲击健身气功跟练。", "预留能够伸展手臂和移动一步的空间|先以小幅度模仿五种动作|脊柱和关节始终在舒适范围移动|整套结束后缓慢收势", "为了模仿形态而过度弯腰或扭转|落脚过重|在疲劳时继续追求动作幅度", .countdown, 825, 60, "无", ["全身", "脊柱活动", "下肢"], difficulty: "入门", breathing: ["跟随口令自然呼吸，避免长时间屏息"], contraindications: ["腰背急性疼痛或平衡障碍时先咨询专业人员"], videoAuthor: "从三十岁开始学拳", videoDurationSeconds: 823),
        e("yijinjing", "易筋经", ["健身气功易筋经", "易筋经十二式"], .traditional, "以连续伸展、转动和站立动作为主的完整健身气功套路。", "先以自然站姿放松肩颈|按口令完成十二式，幅度以无痛为准|上下肢动作保持缓慢连续|收势后让呼吸和心率逐渐恢复", "过度拉伸追求幅度|锁死膝关节|耸肩憋气", .countdown, 766, 60, "无", ["全身", "肩背", "下肢"], difficulty: "入门", breathing: ["自然呼吸优先，动作熟练后再学习专项呼吸配合"], contraindications: ["急性腰背、肩关节损伤时不要强行练习"], videoAuthor: "从三十岁开始学拳", videoDurationSeconds: 766),
        e("liuzijue", "六字诀", ["健身气功六字诀", "六字诀养生功"], .traditional, "配合六种呼气发音和舒缓动作的健身气功跟练。", "选择安静通风的位置自然站立|先以普通音量学习六种呼气发音|动作保持放松并按自身呼吸长度完成|出现气短时停止发音并恢复自然呼吸", "刻意延长呼气导致缺氧|大声用力喊字|为了动作幅度屏住呼吸", .countdown, 758, 60, "无", ["呼吸协调", "全身", "肩背"], difficulty: "入门", breathing: ["不要追求把气完全呼尽", "每次发音后的吸气应自然、安静"], contraindications: ["呼吸系统急性不适、胸闷或头晕时停止练习并根据情况就医"], videoAuthor: "八段锦郝帅", videoDurationSeconds: 758)
    ]

    /// Reviewed, action-specific Bilibili demonstrations. Category guides below are
    /// retained as fallback sources when a primary link becomes unavailable.
    private static let tutorialVideos: [String: String] = [
        "cat-cow": "https://www.bilibili.com/video/BV1dd4y1N7RM/",
        "high-knees": "https://www.bilibili.com/video/BV1H34y147Xq/",
        "plank": "https://www.bilibili.com/video/BV14i421d79i/",
        "bird-dog": "https://www.bilibili.com/video/BV1bKKVzEEHP/",
        "child-pose": "https://www.bilibili.com/video/BV1eD4y1m7VU/",
        "bodyweight-squat": "https://www.bilibili.com/video/BV1bX4y1K7nu/",
        "dead-bug": "https://www.bilibili.com/video/BV1zYL8zTEcV/",
        "wall-stand": "https://www.bilibili.com/video/BV14U4y1Q7Do/",
        "ytwl": "https://www.bilibili.com/video/BV1zq4y197rR/",
        "air-rope": "https://www.bilibili.com/video/BV1cq4y157Gq/",
        "chest-opener": "https://www.bilibili.com/video/BV163411y78Y/",
        "mountain-climber": "https://www.bilibili.com/video/BV1D24y1t7CD/",
        "seated-knee-tuck": "https://www.bilibili.com/video/BV1XomXYhEDZ/",
        "side-plank-hip-lift": "https://www.bilibili.com/video/BV1zCcozVEuG/",
        "cobra": "https://www.bilibili.com/video/BV1SktVzuEG3/",
        "wall-arm-raise": "https://www.bilibili.com/video/BV1Mo4y1Y7m2/",
        "arm-circle": "https://www.bilibili.com/video/BV1Py4y1r7ud/",
        "jumping-jack": "https://www.bilibili.com/video/BV1bE411t7Xe/",
        "wall-push-up": "https://www.bilibili.com/video/BV1SEbazhEMk/",
        "push-up": "https://www.bilibili.com/video/BV1MK4y1r78V/",
        "glute-bridge": "https://www.bilibili.com/video/BV1wt411E7W3/",
        "reverse-lunge": "https://www.bilibili.com/video/BV1zLLH6iECA/",
        "calf-raise": "https://www.bilibili.com/video/BV1Vs421M7gV/",
        "superman": "https://www.bilibili.com/video/BV1SN411f7Ai/",
        "thoracic-rotation": "https://www.bilibili.com/video/BV1gT421Y7Fq/",
        "hamstring-stretch": "https://www.bilibili.com/video/BV1ksqwBeEvD/",
        "march": "https://www.bilibili.com/video/BV1JB4y1w7WF/",
        "shoulder-roll": "https://www.bilibili.com/video/BV1Py4y1r7ud/",
        "wrist-circle": "https://www.bilibili.com/video/BV19U4y127Md/",
        "hip-circle": "https://www.bilibili.com/video/BV1af42197SE/",
        "ankle-circle": "https://www.bilibili.com/video/BV1R3UGBVEV6/",
        "leg-swing-side": "https://www.bilibili.com/video/BV1NF4m1A75Y/",
        "bodyweight-good-morning": "https://www.bilibili.com/video/BV1JN4y1T7QY/",
        "world-greatest-stretch": "https://www.bilibili.com/video/BV1Rb411a7cQ/?p=2",
        "forward-lunge": "https://www.bilibili.com/video/BV1Ny4y1P72p/",
        "db-step-up": "https://www.bilibili.com/video/BV1ms421T7de/",
        "db-overhead-extension": "https://www.bilibili.com/video/BV1wm6dBFEd8/",
        "barbell-rdl": "https://www.bilibili.com/video/BV1Q44y1Z7Xq/",
        "barbell-good-morning": "https://www.bilibili.com/video/BV1ye411b7oH/",
        "machine-shoulder-press": "https://www.bilibili.com/video/BV1nytbeCENC/",
        "assisted-pull-up": "https://www.bilibili.com/video/BV1pX4y1474m/",
        "burpee": "https://www.bilibili.com/video/BV1by4y1y7Ux/",
        "fast-feet": "https://www.bilibili.com/video/BV1tLMuzkEUk/",
        "skater-jump": "https://www.bilibili.com/video/BV1hniqYDExG/?p=3",
        "squat-jump": "https://www.bilibili.com/video/BV1FQ4y1k7uf/",
        "shadow-rope": "https://www.bilibili.com/video/BV1tN4y1D7zx/",
        "doorway-chest-stretch": "https://www.bilibili.com/video/BV1HU9MBcEdA/",
        "lat-stretch": "https://www.bilibili.com/video/BV13D4y1h72b/",
        "rear-shoulder-stretch": "https://www.bilibili.com/video/BV1eH4y1n7wm/",
        "triceps-stretch": "https://www.bilibili.com/video/BV13b41177pv/",
        "hip-flexor-stretch": "https://www.bilibili.com/video/BV1Exd4B1E2K/",
        "quad-stretch": "https://www.bilibili.com/video/BV1Rt4y1E7VN/",
        "calf-wall-stretch": "https://www.bilibili.com/video/BV1EQqVYKEsL/?p=8",
        "step-jack": "https://www.bilibili.com/video/BV1cG411b7FQ/",
        "heel-kick": "https://www.bilibili.com/video/BV1bq4y1i7Rm/",
        "toe-touch": "https://www.bilibili.com/video/BV1jk4y117eK/",
        "scapular-push-up": "https://www.bilibili.com/video/BV1D7tLe9En1/",
        "prone-y-raise": "https://www.bilibili.com/video/BV1afoaBHEC2/",
        "clamshell": "https://www.bilibili.com/video/BV1cG411U7Er/",
        "fire-hydrant": "https://www.bilibili.com/video/BV11r4y1A7LD/",
        "donkey-kick": "https://www.bilibili.com/video/BV1ww411A7fy/",
        "pallof-press": "https://www.bilibili.com/video/BV1dk4y1i74R/",
        "cable-woodchop": "https://www.bilibili.com/video/BV1y14y1V7R8/",
        "db-front-raise": "https://www.bilibili.com/video/BV1Ce4y1c7JA/",
        "barbell-shrug": "https://www.bilibili.com/video/BV1Lh4y1Y7oe/",
        "hack-squat": "https://www.bilibili.com/video/BV1NX4y1h72d/",
        "seated-leg-curl": "https://www.bilibili.com/video/BV1Hx4y1Y7TN/",
        "db-one-arm-row": "https://www.bilibili.com/video/BV1rp411Z7ni/",
        "db-lateral-raise": "https://www.bilibili.com/video/BV1n8411j7uE/",
        "barbell-back-squat": "https://www.bilibili.com/video/BV1cB4y1T77F/",
        "barbell-deadlift": "https://www.bilibili.com/video/BV1N14y1e734/",
        "lat-pulldown": "https://www.bilibili.com/video/BV1aZ421t7NS/",
        "seated-cable-row": "https://www.bilibili.com/video/BV1y14y1X7by/",
        "leg-swing-front": "https://www.bilibili.com/video/BV1NF4m1A75Y/",
        "wall-ankle-mobility": "https://www.bilibili.com/video/BV1mf4y1s74A/",
        "sumo-squat": "https://www.bilibili.com/video/BV1n44y1g7sU/",
        "wall-sit": "https://www.bilibili.com/video/BV1MscszTEJH/",
        "lateral-lunge": "https://www.bilibili.com/video/BV19L4y1E71Y/",
        "split-squat": "https://www.bilibili.com/video/BV1Bu411z7fp/",
        "bulgarian-split-squat": "https://www.bilibili.com/video/BV12Hpez1EVv/",
        "single-leg-glute-bridge": "https://www.bilibili.com/video/BV1ys421T7gZ/",
        "knee-push-up": "https://www.bilibili.com/video/BV1pN4y157rD/",
        "incline-push-up": "https://www.bilibili.com/video/BV1ua411z7Eu/",
        "bench-dip": "https://www.bilibili.com/video/BV1TqKt6VEmY/",
        "high-plank": "https://www.bilibili.com/video/BV1TqoUYwEKi/",
        "side-plank": "https://www.bilibili.com/video/BV1eF3tzjEMk/",
        "crunch": "https://www.bilibili.com/video/BV1C8AfeMEwT/",
        "reverse-crunch": "https://www.bilibili.com/video/BV1hb4y1a7Rd/",
        "lying-leg-raise": "https://www.bilibili.com/video/BV18d4y137pp/",
        "russian-twist": "https://www.bilibili.com/video/BV1AF411i7yq/",
        "bicycle-crunch": "https://www.bilibili.com/video/BV13cR9Y5EAi/",
        "hollow-hold": "https://www.bilibili.com/video/BV19QLw6MEp3/",
        "bear-plank": "https://www.bilibili.com/video/BV1eo1TB4Eax/",
        "db-rdl": "https://www.bilibili.com/video/BV1mTSkBHErk/",
        "db-lunge": "https://www.bilibili.com/video/BV1RHJH6KEms/",
        "db-goblet-squat": "https://www.bilibili.com/video/BV1aa4y1R7TL/",
        "db-bench-press": "https://www.bilibili.com/video/BV1UT411P7wS/",
        "db-incline-press": "https://www.bilibili.com/video/BV1nNZRY3EJc/",
        "db-fly": "https://www.bilibili.com/video/BV15t411z7AR/",
        "db-bent-row": "https://www.bilibili.com/video/BV1vU411o7ba/",
        "db-shoulder-press": "https://www.bilibili.com/video/BV14W41157YH/",
        "db-rear-fly": "https://www.bilibili.com/video/BV16S4y1s7we/",
        "db-curl": "https://www.bilibili.com/video/BV1bRDgYCEgm/",
        "hammer-curl": "https://www.bilibili.com/video/BV1iJ411U72E/",
        "kb-deadlift": "https://www.bilibili.com/video/BV19yCFBeEhs/",
        "kb-swing": "https://www.bilibili.com/video/BV1VHxKzXEgq/",
        "barbell-front-squat": "https://www.bilibili.com/video/BV1gm3c6JEvD/",
        "barbell-hip-thrust": "https://www.bilibili.com/video/BV1Dt4y1a7EV/",
        "barbell-bench-press": "https://www.bilibili.com/video/BV16i421h71B/",
        "barbell-overhead-press": "https://www.bilibili.com/video/BV1jW411x7VR/",
        "barbell-row": "https://www.bilibili.com/video/BV1zS2BBxEFn/",
        "barbell-curl": "https://www.bilibili.com/video/BV1nb4y1M7By/",
        "face-pull": "https://www.bilibili.com/video/BV1wZ421e7K2/",
        "cable-chest-fly": "https://www.bilibili.com/video/BV1F3411i78u/",
        "cable-lateral-raise": "https://www.bilibili.com/video/BV1Qj411h7tS/",
        "cable-curl": "https://www.bilibili.com/video/BV1sw4m1k7JV/",
        "triceps-pushdown": "https://www.bilibili.com/video/BV1fjMyzZEt5/",
        "leg-press": "https://www.bilibili.com/video/BV1BL4y1L7wt/",
        "leg-extension": "https://www.bilibili.com/video/BV1Pj411y7fy/",
        "lying-leg-curl": "https://www.bilibili.com/video/BV1Vj411x73r/",
        "machine-chest-press": "https://www.bilibili.com/video/BV1cUevzTEb4/",
        "pec-deck": "https://www.bilibili.com/video/BV1fTyVYDE1j/",
        "butterfly-stretch": "https://www.bilibili.com/video/BV1Fgd8BWEMH/",
        "farmers-carry": "https://www.bilibili.com/video/BV1Zx4y1M79b/",
        "baduanjin": "https://www.bilibili.com/video/BV1X4oKB7E17/",
        "taiji-eight-methods-five-steps": "https://www.bilibili.com/video/BV1dx411R75W/",
        "simplified-taiji-24": "https://www.bilibili.com/video/BV1334y1m7GD/",
        "wuqinxi": "https://www.bilibili.com/video/BV1J3411s7Ph/",
        "yijinjing": "https://www.bilibili.com/video/BV1sF411F7Tg/",
        "liuzijue": "https://www.bilibili.com/video/BV1mTEc6wEss/"
    ]

    static func fallbackTutorialVideo(
        for id: String,
        category: ExerciseLibraryItem.Category
    ) -> URL? {
        if let specific = tutorialVideos[id] { return URL(string: specific) }
        let value: String
        switch category {
        case .warmup, .mobility:
            value = "https://www.bilibili.com/video/BV1jk4y117eK/"
        case .strength, .cardio:
            value = "https://www.bilibili.com/video/BV1Gy4y1n7Pv/"
        case .core:
            value = "https://www.bilibili.com/video/BV1Qp4y1x7E7/"
        case .cooldown:
            value = "https://www.bilibili.com/video/BV1gD421p7kN/"
        case .dumbbell:
            value = "https://www.bilibili.com/video/BV1sq4y1s73S/"
        case .barbell:
            value = "https://www.bilibili.com/video/BV1py4y1T7F6/"
        case .machine:
            value = "https://www.bilibili.com/video/BV1GTaBevEhL/"
        case .traditional:
            value = "https://www.bilibili.com/video/BV1X4oKB7E17/"
        case .custom:
            return nil
        }
        return URL(string: value)
    }

    static func alternateTutorialVideos(
        for id: String,
        category: ExerciseLibraryItem.Category
    ) -> [URL]? {
        guard tutorialVideos[id] != nil else { return nil }
        let value: String
        switch category {
        case .warmup, .mobility: value = "https://www.bilibili.com/video/BV1jk4y117eK/"
        case .strength, .cardio: value = "https://www.bilibili.com/video/BV1Gy4y1n7Pv/"
        case .core: value = "https://www.bilibili.com/video/BV1Qp4y1x7E7/"
        case .cooldown: value = "https://www.bilibili.com/video/BV1gD421p7kN/"
        case .dumbbell: value = "https://www.bilibili.com/video/BV1sq4y1s73S/"
        case .barbell: value = "https://www.bilibili.com/video/BV1py4y1T7F6/"
        case .machine: value = "https://www.bilibili.com/video/BV1GTaBevEhL/"
        case .traditional: value = "https://www.bilibili.com/video/BV1X4oKB7E17/"
        case .custom: return nil
        }
        guard let url = URL(string: value) else { return nil }
        if url != fallbackTutorialVideo(for: id, category: category) { return [url] }
        let secondary: String
        switch category {
        case .warmup, .mobility: secondary = "https://www.bilibili.com/video/BV1Rb411a7cQ/"
        case .strength, .cardio: secondary = "https://www.bilibili.com/video/BV1jk4y117eK/"
        case .core: secondary = "https://www.bilibili.com/video/BV1Gy4y1n7Pv/"
        case .cooldown: secondary = "https://www.bilibili.com/video/BV1jk4y117eK/"
        case .dumbbell: secondary = "https://www.bilibili.com/video/BV1Gy4y1n7Pv/"
        case .barbell: secondary = "https://www.bilibili.com/video/BV1sq4y1s73S/"
        case .machine: secondary = "https://www.bilibili.com/video/BV1py4y1T7F6/"
        case .traditional: secondary = "https://www.bilibili.com/video/BV1dx411R75W/"
        case .custom: return nil
        }
        return URL(string: secondary).map { [$0] }
    }

    private static func e(
        _ id: String, _ name: String, _ aliases: [String], _ category: ExerciseLibraryItem.Category,
        _ summary: String, _ steps: String, _ mistakes: String,
        _ tracking: PlannedExercise.TrackingMode, _ duration: Int?, _ rest: Int,
        _ equipment: String, _ muscles: [String], _ safety: String? = nil,
        difficulty: String? = nil, breathing: [String]? = nil,
        contraindications: [String]? = nil, videoAuthor: String? = nil,
        videoDurationSeconds: Int? = nil
    ) -> ExerciseLibraryItem {
        var result = ExerciseLibraryItem(
            id: id,
            name: name,
            aliases: aliases,
            category: category,
            summary: summary,
            instructions: steps.components(separatedBy: "|"),
            commonMistakes: mistakes.components(separatedBy: "|"),
            defaultTrackingMode: tracking,
            defaultDurationSeconds: duration,
            defaultRestSeconds: rest,
            videoURL: fallbackTutorialVideo(for: id, category: category),
            isCustom: false,
            englishName: id.replacingOccurrences(of: "-", with: " ").capitalized,
            equipment: equipment,
            primaryMuscles: muscles,
            safetyNotes: [safety ?? "出现疼痛、眩晕或动作失控时立即停止"],
            difficulty: difficulty ?? defaultDifficulty(category: category, id: id),
            breathingNotes: breathing ?? defaultBreathing(tracking),
            contraindications: contraindications ?? ["急性损伤、明显疼痛或医生要求限制活动时暂缓练习"],
            videoAuthor: videoAuthor,
            videoDurationSeconds: videoDurationSeconds
        )
        result.alternateVideoURLs = alternateTutorialVideos(for: id, category: category)
        result.videoReviewStatus = .reviewed
        result.videoReviewedAt = Date(timeIntervalSince1970: 1_786_464_000)
        return result
    }

    private static func defaultDifficulty(category: ExerciseLibraryItem.Category, id: String) -> String {
        let advanced = ["bulgarian-split-squat", "single-leg-glute-bridge", "bench-dip", "hollow-hold", "burpee", "skater-jump", "squat-jump"]
        if advanced.contains(id) || category == .barbell || category == .machine { return "中级" }
        return "入门"
    }

    private static func defaultBreathing(_ tracking: PlannedExercise.TrackingMode) -> [String] {
        tracking == .repetitions
            ? ["保持连续呼吸，发力阶段呼气，返回阶段吸气"]
            : ["保持自然均匀呼吸，不要憋气"]
    }
}
