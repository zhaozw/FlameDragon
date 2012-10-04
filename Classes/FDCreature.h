//
//  FDCreature.h
//  FlameDragon
//
//  Created by sui toney on 11-11-3.
//  Copyright 2011 ms. All rights reserved.
//

#import "FDBattleObject.h"
#import "FDAnimation.h"
#import "FDRange.h"
#import "CreatureData.h"
//#import "FDCreatureAnimation.h"
#import "CreatureDefinition.h"
//#import "CreatureRecord.h"

typedef enum CreatureType {
	CreatureType_Friend,
	CreatureType_Enemy,
	CreatureType_Npc	
} CreatureType;

typedef enum GestureStatus {
	GestureStatus_Idle,
	GestureStatus_MovingUp,
	GestureStatus_MovingDown,
	GestureStatus_MovingLeft,
	GestureStatus_MovingRight	
} GestureStatus;

typedef enum ActionStatus {
	ActionStatus_Idle,
	ActionStatus_MoveFinished,
	ActionStatus_ActionFinished,
	ActionStatus_Dead
} ActionStatus;


@interface FDCreature : FDBattleObject {

	CreatureType creatureType;
	
	int creatureId;
	//int creatureDefId;
	
	// Property
	// All the properties are moved to CreatureData class
	/*
	int level;
	
	int hpMax;
	int mpMax;
	int hpCurrent;
	int mpCurrent;
	
	int ap;
	int dp;
	int dx;
	int mv;
	
	int ex;
	//int baseExp;
	
	
	NSMutableArray *magicList;
	NSMutableArray *itemList;
	
	 int attackItemIndex;
	 int defendItemIndex;
	 */
	FDRange *attackRange;
	
	CreatureData *data;
	
	int hpPrevious;
	int mpPrevious;
	
	// Properties in turn
	BOOL hasMoved;
	BOOL hasActioned;
	//BOOL hasEndedTurn;
	
	GestureStatus gestureStatus;
	ActionStatus actionStatus;
	
	FDAnimation *currentAnimation;

	//FDCreatureAnimation *animationDefinition;
	
	CreatureDefinition *definition;
	
	// TODO: this should be deprecated, should use [definition getDefId]
	int animationDefId;
	
	int lastGainedExperience;
}

//-(id) initWithSprite:(FDSprite *)s;
-(id) initWithAni:(int)aniId Id:(int)i;
-(id) initWithDefinition:(int)identity Id:(int)i Data:(CreatureData *)data;
-(id) initWithDefinition:(int)identity Id:(int)i;
//-(id) initWithSavedState:(int)record;
//-(id) initWithSavedState:(CreatureRecord *)record;

//-(CreatureRecord *) generateRecord;
-(int) getIdentifier;
-(CreatureDefinition *) getDefinition;
-(CreatureType) getCreatureType;

-(void) setActionStatus:(ActionStatus) as;

-(void) setGestureStatus:(GestureStatus) gs;

-(void) updateAnimation;

-(void) preMove:(CGPoint)pos;
-(void) postMove:(CGPoint)pos;

-(int) updateHP:(int)delta;
-(int) updateMP:(int)delta;

-(NSString *) updateExpAndLevelUp;
-(NSString *) levelUp;

//-(void) sleep;

-(void) startTurn;
-(void) endTurn;

-(FDRange *) attackRange;

-(int) getMagicId:(int) index;
-(int) getItemId:(int) index;
-(BOOL) isItemListFull;

-(void) removeItem:(int)index;
-(void) addItem:(int)itemId;

-(void) equipEquipment:(int) index;
-(void) dropItem:(int) index;
-(void) pickItem:(int) itemId;

-(NSString *) getName;

-(AttackItemDefinition *) getAttackItem;
-(DefendItemDefinition *) getDefendItem;

// Calculated Values
-(int) hit;
-(int) ev;
-(int) ap;
-(int) dp;

@property (nonatomic) BOOL hasMoved, hasActioned;
@property (nonatomic) int hpPrevious, mpPrevious;
@property (nonatomic) int lastGainedExperience;
@property (nonatomic, retain) CreatureData *data;

@end
