//
//  AIMagicalDelegate.m
//  FlameDragon
//
//  Created by sui toney on 12-11-8.
//  Copyright 2012 ms. All rights reserved.
//

#import "AIMagicalDelegate.h"
#import "MagicDefinition.h"
#import "DataDepot.h"

@implementation AIMagicalDelegate

-(id) initWithCreature:(FDCreature *)c Layers:(ActionLayers *)l
{
	self = [super initWithCreature:c Layers:l];
	
	[self initDistanceResolver];
	
	return self;
}

-(void) takeAction
{
	NSLog(@"AIMagicalDelegate take action on creature %d", [creature getIdentifier]);
	if (!creature.pendingAction) {
		
		[self takeMagicAction];
	} else {
		
		[self takePendAction];
	}
}

-(void) takeMagicAction
{
	BattleField *field = [[layers getFieldLayer] getField];
	
	MagicDefinition *magic = [self getAvailableMagic];
	
	if (magic == nil) {
		[layers appendToCurrentActivityMethod:@selector(creaturePendAction:) Param1:creature Param2:nil];
		return;
	}
	
	FDCreature *candidate = nil;
	if (magic.magicType == MagicType_Attack) {
		candidate = [self findAffensiveTarget:magic];
	}
	else if (magic.magicType == MagicType_Recover) {
		candidate = [self findDefensiveTarget:magic];
	}
	
	if (candidate == nil) {
		[layers appendToCurrentActivityMethod:@selector(creaturePendAction:) Param1:creature Param2:nil];
		return;
	}
	
	// Use Magic
	CGPoint position = [field getObjectPos:candidate];
	[field setCursorTo:position];
	
	[layers magicFrom:creature TargetPos:position Id:magic.identifier];
	[layers appendToCurrentActivityMethod:@selector(creatureEndTurn:) Param1:creature Param2:nil];
}

-(void) takePendAction
{
	BattleField *field = [[layers getFieldLayer] getField];

	CGPoint targetPos = [self generatePos:[field getObjectPos:[self findTarget]]];
	[field setCursorTo:targetPos];
	[layers moveCreature:creature To:targetPos showMenu:FALSE];

	[layers appendToCurrentActivityMethod:@selector(creatureEndTurn:) Param1:creature Param2:nil];
}

-(FDCreature *) findAffensiveTarget:(MagicDefinition *)magic
{
	BattleField *field = [[layers getFieldLayer] getField];
	
	NSMutableArray *candidateList = [[NSMutableArray alloc] init];
	[candidateList addObjectsFromArray:[field getFriendList]];
	[candidateList addObjectsFromArray:[field getNpcList]];
	
	FDCreature *candidate = nil;
	for (FDCreature *c in candidateList) {
		
		float distance = [field getDirectDistance:creature And:c];
		
		if (distance <= magic.effectScope + magic.effectRange) {
			if (candidate == nil || candidate.data.hpCurrent > c.data.hpCurrent) {
				candidate = c;
			}
		}
	}
	
	[candidateList release];
	return candidate;
}

-(FDCreature *) findDefensiveTarget:(MagicDefinition *)magic
{
	BattleField *field = [[layers getFieldLayer] getField];
	
	NSMutableArray *candidateList = [[NSMutableArray alloc] init];
	[candidateList addObjectsFromArray:[field getEnemyList]];
	
	FDCreature *candidate = nil;
	for (FDCreature *c in candidateList) {
		
		float distance = [field getDirectDistance:creature And:c];
		
		if (distance <= magic.effectScope + magic.effectRange) {
			if (c.data.hpCurrent < c.data.hpMax && (candidate == nil || candidate.data.hpCurrent > c.data.hpCurrent)) {
				candidate = c;
			}
		}
	}
	
	[candidateList release];
	return candidate;
}

-(MagicDefinition *) getAvailableMagic
{
	if ([creature.data.magicList count] == 0) {
		return nil;
	}
	
	for (int index = [creature.data.magicList count] - 1; index >= 0; index--) {
		NSNumber *magicId = [creature.data.magicList objectAtIndex:0];
		MagicDefinition *magic = [[DataDepot depot] getMagicDefinition:[magicId intValue]];
	
		if (magic == nil) {
			continue;
		}
		
		if (creature.data.mpCurrent >= magic.mpCost) {
			return magic;
		}
	}
	
	return nil;
}

@end