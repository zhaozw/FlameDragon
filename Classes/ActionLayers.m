//
//  ActionLayers.m
//  FlameDragon
//
//  Created by sui toney on 11-11-19.
//  Copyright 2011 ms. All rights reserved.
//

#import "ActionLayers.h"
#import "BattleField.h"
#import "FDMoveCreatureActivity.h"
#import "FDExplodeActivity.h"
#import "FDTalkActivity.h"
#import "GameFormula.h"
#import "FDOperationActivity.h"
#import "TurnInfo.h"
#import "FDEmptyActivity.h"
#import "UsableItemDefinition.h"
#import "DataDepot.h"
#import "ItemBox.h"
#import "MagicBox.h"
#import "ChapterInfo.h"
#import "FDLocalString.h"
#import "FightScene.h"
#import "MainGameScene.h"
#import "GameWinScene.h"
#import "GameOverScene.h"
#import "TitleScene.h"
#import "GameRecord.h"
#import "VillageScene.h"


@implementation ActionLayers

-(id) initWithField:(BattleFieldLayer *)fLayer Message:(MessageLayer *)mLayer
{
	self = [super init];
	
	fieldLayer = fLayer;
	messageLayer = mLayer;
	
	field = [fieldLayer getField];
	
	activityList = [[NSMutableArray alloc] init];

	isLocked = FALSE;
	
	synchronizeTick = 0;
	SYNCHRONIZE_TOTAL_INT = 1000;

	sideBar = [[SideBar alloc] init];
	[sideBar show:messageLayer];
	
	return self;
}

-(BattleFieldLayer *) getFieldLayer
{
	return fieldLayer;
}

-(MessageLayer *) getMessageLayer
{
	return messageLayer;
}

-(void) takeTick
{
	synchronizeTick = (synchronizeTick + 1) % SYNCHRONIZE_TOTAL_INT;

	[messageLayer updateScreen:synchronizeTick];
	
	if ([messageLayer getMessage] != nil) {
		// The message should block all the other ticks
		return;
	}
	
	[fieldLayer updateScreen:synchronizeTick];
	
	for (FDActivity *activity in activityList) {
		
		[activity takeTick:synchronizeTick];
		
		if ([activity hasFinished]) {
			
			//[activity postActivity];
			if ([activity getNext] != nil) {
				[activityList addObject:[activity getNext]];
			}
			
			[activityList removeObject:activity];
		}
	}
}

-(void) appendNewActivity:(FDActivity *)activity
{
	[activityList addObject:activity];
}

-(void) appendToMainActivity:(FDActivity *)activity
{
	FDActivity *last = [activityList count] > 0 ? [activityList objectAtIndex:0] : nil;
	if (last == nil)
	{
		[activityList addObject:activity];
	}
	else {
		[last appendToLast:activity];
	}
}

-(void) clearAllActivity
{
	[activityList removeAllObjects];
}

-(void) appendToCurrentActivity:(FDActivity *)activity
{
	FDActivity *last = [activityList count] > 0 ? [activityList objectAtIndex:[activityList count]-1] : nil;
	if (last == nil)
	{
		[activityList addObject:activity];
	}
	else {
		[last appendToNext:activity];
	}	
}

-(void) appendToMainActivityMethod:(SEL)method Param1:(id)obj1 Param2:(id)obj2
{
	[self appendToMainActivityMethod:method Param1:obj1 Param2:obj2 Obj:self];
}

-(void) appendToMainActivityMethod:(SEL)method Param1:(id)obj1 Param2:(id)obj2 Obj:(id)obj
{
	FDOperationActivity *activity = [[FDOperationActivity alloc] initWithObject:obj Method:method Param1:obj1 Param2:obj2];
	[self appendToMainActivity:activity];
	[activity release];	
}


-(void) appendToCurrentActivityMethod:(SEL)method Param1:(id)obj1 Param2:(id)obj2
{
	[self appendToCurrentActivityMethod:method Param1:obj1 Param2:obj2 Obj:self];
}

-(void) appendToCurrentActivityMethod:(SEL)method Param1:(id)obj1 Param2:(id)obj2 Obj:(id)obj
{
	FDOperationActivity *activity = [[FDOperationActivity alloc] initWithObject:obj Method:method Param1:obj1 Param2:obj2];
	[self appendToCurrentActivity:activity];
	[activity release];	
}

-(void) prepareToMove:(FDCreature *)creature Location:(CGPoint)location
{
	// Show Creature Info
	
	creatureInfo = [[CreatureInfoBar alloc] initWithCreature:creature ClickedOn:location];
	[creatureInfo show:messageLayer];
}

-(void) clearCreatureInfo
{
	if (creatureInfo != nil) {
		[creatureInfo close];
		creatureInfo = nil;
	}
}

-(void) moveCreatureId:(int)creatureId To:(CGPoint)pos showMenu:(BOOL)willShowMenu
{
	FDCreature *creature = [field getCreatureById:creatureId];
	[self moveCreature:creature To:pos showMenu:willShowMenu];
}

-(void) moveCreature:(FDCreature *)creature To:(CGPoint)pos showMenu:(BOOL)willShowMenu
{
	// Set Cursor
	[field setCursorTo:[field getObjectPos:creature]];
	[field setCursorTo:pos];
	
	FDPath *path = [[[fieldLayer getField] getMovePath:creature To:pos] retain];
	
	for (int i = 0; i < [path getPosCount]; i++) {		
		[self moveCreatureSimple:creature To:[path getPos:i]];
	}
	
	if (![FDPosition isEqual:[field getObjectPos:creature] With:pos]) {
		creature.hasMoved = TRUE;
	}
	
	if (willShowMenu)
	{
		CGPoint p = [path getTargetPos];
		[self appendToMainActivityMethod:@selector(showMenuO:At:) Param1:[NSNumber numberWithInt: 1] Param2:[FDPosition positionX:p.x Y:p.y] Obj:field];
	}
	[path release];
}

-(void) moveCreatureIdSimple:(int)creatureId To:(CGPoint)pos
{
	FDCreature *creature = [field getCreatureById:creatureId];
	[self moveCreatureSimple:creature To:pos];
}

-(void) moveCreatureSimple:(FDCreature *)creature To:(CGPoint)pos
{
	CGPoint loc = [field convertPosToLoc:pos];
	
	FDMoveCreatureActivity *act = [[FDMoveCreatureActivity alloc] initWithObject:creature ToLocation:loc Speed:1.8];
	[self appendToCurrentActivity:act];
	[act release];
}

-(void) attackFrom:(FDCreature *)creature Target:(FDCreature *)target
{
	NSLog(@"Attack from A to B. ");
	
	[GameFormula getExperienceFromAttack:creature Target:target Field:field];

	//NSLog(@"Get Experience: %d", exp);
	
	// Check fight back
	BOOL fightBack = [field isNextTo:creature And:target] && target.data.hpCurrent > 0;
	if (fightBack) {
		
		// Fight back
		[GameFormula getExperienceFromAttack:target Target:creature Field:field];
	}
	else {
		[creature updateHP:0];
	}

	// Show the Fight Scene
	FightScene *scene = [[FightScene alloc] init];
	[[CCDirector sharedDirector] pushScene: [CCTransitionFade transitionWithDuration:0.5 scene:scene]];
	
	CGPoint pos = [field getObjectPos:creature];
	int backId = [field getBackgroundPicId:pos];
	
	NSMutableArray *targets = [[NSMutableArray alloc] init];
	[targets addObject:target];
	
	[scene setParameter:backId Self:creature Targets:targets FightBack:fightBack];
	[scene start];
	
	[scene setPostMethod:@selector(postFightAction:Targets:) param1:creature param2:targets Obj:self];

}

-(void) postFightAction:(FDCreature *)creature Targets:(NSMutableArray *)targets
{
	NSLog(@"Post Method for attacking.");
	
	// Check whether the important game event is triggered
	[eventListener isNotified];

	if (creature.data.hpCurrent <= 0) {
		
		FDExplodeActivity *activity = [[FDExplodeActivity alloc] initWithObject:creature Field:field];
		[self appendToCurrentActivity:activity];
		[activity release];
	}
	
	for (FDCreature *target in targets) {
		
			if (target.data.hpCurrent <= 0) {
				FDExplodeActivity *activity = [[FDExplodeActivity alloc] initWithObject:target Field:field];
				[self appendToCurrentActivity:activity];
				[activity release];
			}
	}
	[targets release];
	
	// Check whether the important game event is triggered
	//[self appendToCurrentActivityMethod:@selector(isNotified) Param1:nil Param2:nil Obj:eventListener];
	// [eventListener isNotified];
	
	// Talk about experience
	FDCreature *talkerFriend = nil;
	FDCreature *target = [targets objectAtIndex:0];
	if ([creature isKindOfClass:[FDFriend class]] && creature.lastGainedExperience > 0 && creature.data.hpCurrent > 0)
	{
		talkerFriend = creature;
	}
	else if (target != nil && [target isKindOfClass:[FDFriend class]] && target.lastGainedExperience > 0 && target.data.hpCurrent > 0)
	{
		talkerFriend = target;
	}
	
	if (talkerFriend != nil) {
	
		NSString *message = [NSString stringWithFormat:[FDLocalString message:5], talkerFriend.lastGainedExperience];
		FDTalkActivity *talk = [[FDTalkActivity alloc] initWithCreature:talkerFriend Message:message Layer:messageLayer];
		[self appendToMainActivity:talk];
		[talk release];
		
		NSString *levelUpMsg = [talkerFriend updateExpAndLevelUp];
		if (levelUpMsg != nil) {
			
			TalkMessage *message = [[TalkMessage alloc] initWithCreature:talkerFriend Message:levelUpMsg];
			[self appendToMainActivityMethod:@selector(show:) Param1:messageLayer Param2:nil Obj:message];
			// [message show:messageLayer];
		}
	}
	
	// Check whether the important game event is triggered
	[self appendToMainActivityMethod:@selector(isNotified) Param1:nil Param2:nil Obj:eventListener];
	
	//End turn
	[self appendToMainActivityMethod:@selector(creatureActionDone:) Param1:creature Param2:nil Obj:self];
}

-(void) magicFrom:(FDCreature *)creature Targets:(NSMutableArray *)targets Id:(int)magicId
{
	NSLog(@"Magic from %d to %d enemies", [creature getIdentifier], [targets count]);
	
	MagicDefinition *magic = [[DataDepot depot] getMagicDefinition:magicId];
	[creature updateMP:-magic.mpCost];
	[creature updateHP:0];
	 
	[GameFormula getExperienceFromMagic:magicId Creature:creature Target:[targets objectAtIndex:0] Field:field];

	// Show the Fight Scene
	FightScene *scene = [[FightScene alloc] init];
	[[CCDirector sharedDirector] pushScene: [CCTransitionFade transitionWithDuration:0.5 scene:scene]];
	
	CGPoint pos = [field getObjectPos:creature];
	int backId = [field getBackgroundPicId:pos];
	
	[scene setParameter:backId Self:creature Targets:targets FightBack:FALSE];
	[scene start];
	
	[scene setPostMethod:@selector(postFightAction:Targets:) param1:creature param2:targets Obj:self];
}

-(void) useItem:(FDCreature *)creature ItemIndex:(int)itemIndex Target:(FDCreature *)target
{
	NSLog(@"Use Item.");
	
	int itemId = [creature getItemId:itemIndex];
	UsableItemDefinition * itemDef = (UsableItemDefinition *)[[DataDepot depot] getItemDefinition:itemId];
	[itemDef usedBy:target];
	
	[creature removeItem:itemIndex];
	
	[self appendToMainActivityMethod:@selector(creatureActionDone:) Param1:creature Param2:nil Obj:self];
}

-(void) giveItem:(FDCreature *)creature ItemIndex:(int)itemIndex Target:(FDCreature *)target
{
	NSLog(@"Gave Item.");
	
	int itemId = [creature getItemId:itemIndex];
	[creature removeItem:itemIndex];
	[target addItem:itemId];
	
	creature.hasActioned = TRUE;
}

-(void) exchangeItem:(FDCreature *)creature ItemIndex:(int)itemIndex Target:(FDCreature *)target ItemIndex:(int)backItemIndex
{
	NSLog(@"Exchange Item.");
	
	int itemId = [creature getItemId:itemIndex];
	int backItemId = [target getItemId:backItemIndex];

	[creature removeItem:itemIndex];
	[target removeItem:backItemIndex];

	[target addItem:itemId];
	[creature addItem:backItemId];

	creature.hasActioned = TRUE;
}

-(void) pickUpTreasure:(FDCreature *) creature
{
	FDTreasure *treasure = [field getTreasureAt:[field getObjectPos:creature]];
	
	if (treasure == nil || [treasure hasOpened]) {
		return;
	}
	
	NSLog(@"Creature picked up the treasure.");
	
	[treasure setOpened];
	ItemDefinition *item = [treasure getItem];
	
	// If the treasure is money, add to money
	if ([item isMoney]) {
		// Add to money
		money += [item getMoneyQuantity];
		return;
	}
	else {
		[creature.data.itemList addObject:[NSNumber numberWithInt:item.identifier]];
	}
}

-(void) exchangeTreasure:(FDCreature *)creature withItem:(int)itemIndex
{
	FDTreasure *treasure = [field getTreasureAt:[field getObjectPos:creature]];
	
	if (treasure == nil || [treasure hasOpened])
	{
		return;
	}
	
	NSLog(@"Exchange picked up the treasure.");
	
	ItemDefinition *item = [treasure getItem];

	// Note: the item could not be money
	
	[creature.data.itemList addObject:[NSNumber numberWithInt:item.identifier]];
	
	[treasure changeItemId:[[creature.data.itemList objectAtIndex:itemIndex] intValue]];

	[creature dropItem:itemIndex];
}

-(void) creatureActionDone:(FDCreature *)creature
{
	if (creature != nil) {
		
		creature.hasActioned = TRUE;
		
		[self appendToCurrentActivityMethod:@selector(creatureEndTurn:) Param1:creature Param2:nil Obj:self];
	}
}

-(void) creatureEndTurn:(FDCreature *)creature
{
	NSLog(@"End turn for creature %d", [creature getIdentifier]);
	
	// Recover some HP
	if (!creature.hasMoved && !creature.hasActioned) {
		int recoverHp = [GameFormula recoverHpFromRest:creature];
		
		NSLog(@"Recover HP %d for creature.", recoverHp);
		[creature updateHP:recoverHp];
	}
	
	[creature endTurn];
	
	if ([creature getCreatureType] == CreatureType_Enemy) {
		//[enemyAiHandler isNotified];
		[self appendToCurrentActivityMethod:@selector(isNotified) Param1:nil Param2:nil Obj:enemyAiHandler];
	}
	if ([creature getCreatureType] == CreatureType_Npc) {
		//[npcAiHandler isNotified];
		[self appendToCurrentActivityMethod:@selector(isNotified) Param1:nil Param2:nil Obj:npcAiHandler];
	}
	
	[self appendToCurrentActivityMethod:@selector(checkEndTurn) Param1:nil Param2:nil Obj:self];
}

-(void) checkEndTurn
{
	if (turnType == TurnType_Friend)
	{
		for (FDCreature *creature in [field getFriendList]) {
			if (!creature.hasActioned) {
			return;
			}
		}
		[self endFriendTurn];
	}
	else if	(turnType == TurnType_NPC)
	{
		for (FDCreature *creature in [field getNpcList]) {
			if (!creature.hasActioned) {
				return;
			}
		}
		[self endNpcTurn];
	}
	else if (turnType == TurnType_Enemy)
	{
		for (FDCreature *creature in [field getEnemyList]) {
			if (!creature.hasActioned) {
				return;
			}
		}
		[self endEnemyTurn];
	}
}

-(void) startFriendTurn
{
	NSLog(@"Start Friend Turn");

	
	turnType = TurnType_Friend;
	
	// reset all creatures
	[field startNewTurn];
	
	// Show the turn Number
	[self appendToMainActivityMethod:@selector(showTurnInfo) Param1:nil Param2:nil];
	
	// Set Cursor the first friend
	FDCreature *firstFriend = [[field getFriendList] objectAtIndex:0];
	CGPoint pos = [field getObjectPos:firstFriend];
	[self appendToMainActivityMethod:@selector(setCursorObjTo:) Param1:[FDPosition positionX:pos.x Y:pos.y] Param2:nil Obj:field];
}

-(void) endFriendTurn
{
	NSLog(@"End Friend Turn");
	
	// End all friends
	for (FDCreature *friend in [field getFriendList]) {
		[self creatureEndTurn:friend];
	}
	
	// Trigger the friend turn actions
	[eventListener isNotified];
	//[npcAiHandler isNotified];
	
	// To Avoid seeing so many disabled friends, enable them just after user interaction finished.
	for (FDCreature *friend in [field getFriendList]) {
		[friend startTurn];
	}
	
	[self appendToMainActivityMethod:@selector(startNpcTurn) Param1:nil Param2:nil];
}

-(void) startNpcTurn
{
	NSLog(@"Start Npc Turn");

	turnType = TurnType_NPC;

	// If there is no NPC
	if ([[field getNpcList] count] > 0) {
		turnType = TurnType_NPC;
		[npcAiHandler isNotified];
	}
	else {
		[self endNpcTurn];
	}
}

-(void) endNpcTurn
{
	NSLog(@"End Npc Turn");
	
	// End all Npcs
	for (FDCreature *npc in [field getNpcList]) {
		[npc endTurn];
	}
	
	// Trigger the Npc turn actions
	[eventListener isNotified];

	// To Avoid seeing so many disabled NPCs, enable them just after user interaction finished.
	for (FDCreature *npc in [field getNpcList]) {
		[npc startTurn];
	}
	
	[self appendToMainActivityMethod:@selector(startEnemyTurn) Param1:nil Param2:nil];
}

-(void) startEnemyTurn
{
	NSLog(@"Start Enemy Turn");

	turnType = TurnType_Enemy;
	[enemyAiHandler isNotified];

}

-(void) endEnemyTurn
{
	NSLog(@"End Enemy Turn");

	// End all enemies
	for (FDCreature *enemy in [field getEnemyList]) {
		[enemy endTurn];
	}
	
	// Trigger Events
	[eventListener isNotified];
		
	// Show new turn
	turnNo ++;
	[self appendToMainActivityMethod:@selector(startFriendTurn) Param1:nil Param2:nil];
}

-(void) startNewGame:(ChapterRecord *)info
{
	//[field loadMapData:level];
	chapterId = info.chapterId;
	turnNo = 0;
	
	// Load Friends
	for(CreatureRecord *record in [info friendRecords])
	{
		FDFriend *creature = [[FDFriend alloc] initWithDefinition:record.definitionId Id:record.creatureId Data:record.data];
		
		if (creature.data.hpCurrent > 0) {
			[[field getUnsettledCreatureList] addObject:creature];
		} else {
			[[field getDeadCreatureList] addObject:creature];
		}

		[creature release];
	}
	
	[self runGame];
}

-(void) loadGame:(BattleRecord *)info // withEvents:(BOOL)loadEvents
{
	//[field loadMapData:info.levelNo];
	
	chapterId = info.chapterId;
	turnNo = info.turnNo;
	money = info.money;
	
	// Load Creatures
	for(CreatureRecord *record in [info friendRecords])
	{
		FDFriend *creature = [[FDFriend alloc] initWithDefinition:record.definitionId Id:record.creatureId Data:record.data];
		[field addFriend:creature Position:record.location];
		[creature release];
		
	}
	
	for(CreatureRecord *record in [info enemyRecords])
	{
		FDEnemy *creature = [[FDEnemy alloc] initWithDefinition:record.definitionId Id:record.creatureId Data:record.data];
		[field addEnemy:creature Position:record.location];
		[creature release];
		
	}
	for(CreatureRecord *record in [info npcRecords])
	{
		FDNpc *creature = [[FDNpc alloc] initWithDefinition:record.definitionId Id:record.creatureId Data:record.data];
		[field addNpc:creature Position:record.location];
		[creature release];
		
	}
	for(CreatureRecord *record in [info deadCreatureRecords])
	{
		FDCreature *creature = [[FDCreature alloc] initWithDefinition:record.definitionId Id:record.creatureId Data:record.data];
		[[field getDeadCreatureList] addObject:creature];
		[creature release];
	}
	
	for (TreasureRecord *record in [info treasureRecords]) {
		FDTreasure *treasure = [field getTreasureAt:record.location];
		if (treasure != nil) {
			
			if (record.hasOpened) {
				[treasure setOpened];
			}
			else {
				[treasure changeItemId:record.itemId];
			}
		}
	}
	
	// Load the active events
	if (!info.withAllEvents) {
		[eventListener loadState:[info activeEventIds]];
	}
	
	turnNo --;	// TODO: bug
	
	[self runGame];
}

-(void) runGame
{
	turnType = TurnType_Friend;
	
	// Trigger Events
	[eventListener isNotified];
	
	// Show new turn
	turnNo ++;
	[self appendToMainActivityMethod:@selector(startFriendTurn) Param1:nil Param2:nil];	
}

-(void) saveGame
{
	NSLog(@"Saving Game");
	
	BattleRecord *info = [[BattleRecord alloc] initWithChapter:chapterId];
	info.turnNo = turnNo;
	info.money = money;
	
	for(FDCreature *creature in [field getFriendList])
	{
		CreatureRecord *record = [field generateCreatureRecord:creature];
		[[info friendRecords] addObject:record];
	}
	
	for(FDCreature *creature in [field getEnemyList])
	{
		CreatureRecord *record = [field generateCreatureRecord:creature];
		[[info enemyRecords] addObject:record];
	}
	
	for(FDCreature *creature in [field getNpcList])
	{
		CreatureRecord *record = [field generateCreatureRecord:creature];
		[[info npcRecords] addObject:record];
	}
	
	for(FDCreature *creature in [field getDeadCreatureList])
	{
		CreatureRecord *record = [field generateCreatureRecord:creature];
		[[info deadCreatureRecords] addObject:record];
	}
	
	NSMutableArray *treasureList = [field getTreasureList];
	for (FDTreasure *treasure in treasureList) {
		TreasureRecord *record = [field generateTreasureRecord:treasure];
		[[info treasureRecords] addObject:record];
	}
	
	NSMutableArray *activeEventIds = [eventListener saveState];
	[[info activeEventIds] addObjectsFromArray:activeEventIds];
	
	
	GameRecord *gameRecord = [[GameRecord readFromSavedFile] retain];
	[gameRecord setBattleRecord:info];
	[gameRecord saveRecord];
	
	[info release];
	[gameRecord release];
}

-(ChapterRecord *) composeChapterRecord
{
	ChapterRecord *record = [[ChapterRecord alloc] initWithChapter:chapterId+1];
	record.money = money;
	
	for(FDCreature *creature in [field getFriendList])
	{
		CreatureRecord *r = [field generateCreatureRecord:creature];
		[[record friendRecords] addObject:r];
	}
	
	for (FDCreature *creature in [field getDeadCreatureList]) {
		if ([creature isKindOfClass:[FDFriend class]]) {
			CreatureRecord *r = [field generateCreatureRecord:creature];
			[[record friendRecords] addObject:r];
		}
	}
	
	return record;
}

-(void) showItemStatus:(FDCreature *)creature
{
	NSLog(@"Show creature item status");
	
	ItemBox *ibox = [[ItemBox alloc] initWithCreature:creature Type:ItemOperatingType_ShowOnly];
	[ibox show:messageLayer];	
}

-(void) showMagicStatus:(FDCreature *)creature
{
	NSLog(@"Show creature magic status");
	
	MagicBox *box = [[MagicBox alloc] initWithCreature:creature Type:MagicOperatingType_ShowOnly];
	[box show:messageLayer];	
}

-(void) showItemStatusAsync:(FDCreature *)creature
{
	[self appendToCurrentActivityMethod:@selector(showItemStatus:) Param1:creature Param2:nil];
}

-(void) showMagicStatusAsync:(FDCreature *)creature
{
	[self appendToCurrentActivityMethod:@selector(showMagicStatus:) Param1:creature Param2:nil];
}

-(void) showTurnInfo
{
	TurnInfo *info = [[TurnInfo alloc] initWithNo:turnNo];
	[info show:messageLayer];
	[info release];
}

-(void) showChapterInfo
{
	ChapterInfo *info = [[ChapterInfo alloc] init];
	
	[info setFriendCount:[[field getFriendList] count] EnemyCount:[[field getEnemyList] count] NpcCount:[[field getNpcList] count]];
	[info setChapterNo:chapterId TurnNo:turnNo];
	[info setCondition:chapterId];
	[info setMoney:money];
	
	[info show:messageLayer];
	[info release];	
}

-(void) gameOver
{
	//[self clearAllActivity];
	
	GameOverScene *scene = [GameOverScene node];
	[[CCDirector sharedDirector] pushScene: [CCTransitionFade transitionWithDuration:0.5 scene:scene]];	
}

-(void) gameWin
{
	//[self clearAllActivity];
	NSLog(@"Game Win.");
	
	//ChapterRecord *record = [ChapterRecord sampleRecord];
	ChapterRecord *record = [self composeChapterRecord];
	
	if (chapterId < 2) {
		VillageScene *scene = [VillageScene node];
		[scene loadWithRecord:record];
		[[CCDirector sharedDirector] pushScene: [CCTransitionFade transitionWithDuration:1.5 scene:scene]];	
	} else {
		GameWinScene *scene = [GameWinScene node];
		[[CCDirector sharedDirector] pushScene: [CCTransitionFade transitionWithDuration:1.5 scene:scene]];	
	}
	
}

-(void) gameQuit
{
	NSLog(@"Game Quit.");
	
	// [self clearAllActivity];
	
	TitleScene *scene = [TitleScene node];
	[[CCDirector sharedDirector] pushScene: [CCTransitionFade transitionWithDuration:1.0 scene:scene]];	
}

-(void) gameContinue
{
	GameRecord *record = [GameRecord readFromSavedFile];
	BattleRecord *info = [record.battleRecord retain];
	//[record saveRecord];
	
	MainGameScene *mainGame = [MainGameScene node];
	[mainGame loadWithInfo:info];
	
	[[CCDirector sharedDirector] pushScene: [CCTransitionFade transitionWithDuration:1.0 scene:mainGame]];
	
	[info release];
}

-(int) getTurnNumber
{
	return turnNo;
}

-(TurnType) getTurnType
{
	return turnType;
}

-(BOOL) isInteractiveBusy
{
	for(FDActivity *activity in activityList)
	{
		if ([activity blocksInteraction]) {
			return TRUE;
		}
	}
	return FALSE;
}

-(BOOL) isLocked
{
	return isLocked;
}


-(void) setEventListener:(IListener *)listener
{
	eventListener = [listener retain];
}

-(void) setEnemyAiHandler:(IListener *)listener
{
	enemyAiHandler = [listener retain];
}

-(void) setNpcAiHandler:(IListener *)listener
{
	npcAiHandler = [listener retain];
}

-(void) showTestData
{
	FDActivity *a = [activityList objectAtIndex:[activityList count]-1];
	while (a !=nil) {
		
		//NSLog([a debugInfo]);
		a = [a getNext];
	}
}

-(void) dealloc
{
	[activityList release];
	
	if (eventListener != nil) {
		[eventListener release];
		eventListener = nil;
	}
	
	if (enemyAiHandler != nil) {
		[enemyAiHandler release];
		enemyAiHandler = nil;
	}
	
	if (npcAiHandler != nil) {
		[npcAiHandler release];
		npcAiHandler = nil;
	}
	
	
	[super dealloc];
	
}


@end