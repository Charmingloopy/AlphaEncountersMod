###################################################################################################
# Author: An Unsocial Pigeon                                                                      #
# Discord: @anunsocialpigeon                                                                      #
# For any issues or inquiries, feel free to reach out on Discord.                                 #
#                                                                                                 #
# You are allowed to use this file in your own mod,                                               # 
# on condition that you correctly credit me (An Unsocial Pigeon) <3                               #
###################################################################################################

###################################################################################################
# Catchable alphas by CharmingLoopy
# makes alphas catchable, makes them know a random move of their type. they have 2 perfect ivs



# MOD SETTINGS REGISTRATION


if defined?(ModSettingsMenu)
  ModSettingsMenu.register(:alpha_encounterchance, {
    name: "Alpha Encounter Chance",
    type: :slider,
    min: 1,
    max: 100,
    interval: 1,
    default: 1,
    description: "Chance to encounter an alpha pokemon (%)",
    category: "Encounters"
 })
  echoln "Loaded Alpha Pokemon Settings"
end


#===============================================================================
# Start a wild battle
#===============================================================================
def pbWildBattleCore(*args)
  alpha_chance = defined?(ModSettingsMenu) ? (ModSettingsMenu.get(:alpha_encounterchance) || 1) : 1
  outcomeVar = $PokemonTemp.battleRules["outcomeVar"] || 1
  canLose    = $PokemonTemp.battleRules["canLose"] || false
  # Skip battle if the player has no able Pokémon, or if holding Ctrl in Debug mode
  if $Trainer.able_pokemon_count == 0 || ($DEBUG && Input.press?(Input::CTRL))
    pbMessage(_INTL("SKIPPING BATTLE...")) if $Trainer.pokemon_count > 0
    pbSet(outcomeVar,1)   # Treat it as a win
    $PokemonTemp.clearBattleRules
    $PokemonGlobal.nextBattleBGM       = nil
    $PokemonGlobal.nextBattleME        = nil
    $PokemonGlobal.nextBattleCaptureME = nil
    $PokemonGlobal.nextBattleBack      = nil
    $PokemonTemp.forced_alt_sprites=nil
    pbMEStop
    return 1   # Treat it as a win
  end
  $PokemonSystem.is_in_battle = true
  # Record information about party Pokémon to be used at the end of battle (e.g.
  # comparing levels for an evolution check)
  Events.onStartBattle.trigger(nil)
  # Generate wild Pokémon based on the species and level
  foeParty = []
  sp = nil
  for arg in args
    if arg.is_a?(Pokemon)
      foeParty.push(arg)
    elsif arg.is_a?(Array)
      species = GameData::Species.get(arg[0]).id
      pkmn = pbGenerateWildPokemon(species,arg[1])
      foeParty.push(pkmn)
    elsif sp
      species = GameData::Species.get(sp).id
      pkmn = pbGenerateWildPokemon(species,arg)
      foeParty.push(pkmn)
      sp = nil
    else
      sp = arg
    end
  end
  alpha_count = 0
  $PokemonTemp.battleRewards ||= []
  for pokemon in foeParty
    alpha = false

    if rand(100) < alpha_chance
      alpha= true
      alpha_count += 1
      alpha_chance  /= 2
    end
    if alpha == true
      make_alpha(pokemon)
      setBattleRule("backdrop", "lava")

      $PokemonTemp.encounterIsAlphaPokemon = true


      # Drops
      $PokemonTemp.battleRewards << ["item", :RARECANDY] if rand(5) < 1 && pokemon.level > 50
      $PokemonTemp.battleRewards << ["item", :POTION] if rand(3) < 1
      $PokemonTemp.battleRewards << ["item", :POTION] if rand(3) < 1
      $PokemonTemp.battleRewards << ["item", :POTION] if rand(3) < 1
      $PokemonTemp.battleRewards << ["item", :SUPERPOTION] if rand(7) < 1 && pokemon.level > 35
      $PokemonTemp.battleRewards << ["item", :SUPERPOTION] if rand(7) < 1 && pokemon.level > 35
      $PokemonTemp.battleRewards << ["item", :REPEL] if rand(5) < 1
      $PokemonTemp.battleRewards << ["item", :REPEL] if rand(5) < 1
      $PokemonTemp.battleRewards << ["item", :POKEBALL] if rand(5) < 1
      $PokemonTemp.battleRewards << ["item", :POKEBALL] if rand(5) < 1

      # Max 3 items


      if rand(100) < 1
        pokemon.shiny = true
      end
    end
  end
  echoln foeParty.inspect
  raise _INTL("Expected a level after being given {1}, but one wasn't found.",sp) if sp
  # Calculate who the trainers and their party are
  playerTrainers    = [$Trainer]
  playerParty       = $Trainer.party
  playerPartyStarts = [0]
  room_for_partner = (foeParty.length > 1)
  if !room_for_partner && $PokemonTemp.battleRules["size"] &&
     !["single", "1v1", "1v2", "1v3"].include?($PokemonTemp.battleRules["size"])
    room_for_partner = true
  end
  if $PokemonGlobal.partner && !$PokemonTemp.battleRules["noPartner"] && room_for_partner
    ally = NPCTrainer.new($PokemonGlobal.partner[1],$PokemonGlobal.partner[0])
    ally.id    = $PokemonGlobal.partner[2]
    ally.party = $PokemonGlobal.partner[3]
    playerTrainers.push(ally)
    playerParty = []
    $Trainer.party.each { |pkmn| playerParty.push(pkmn) }
    playerPartyStarts.push(playerParty.length)
    ally.party.each { |pkmn| playerParty.push(pkmn) }
    setBattleRule("double") if !$PokemonTemp.battleRules["size"]
  end
  # Create the battle scene (the visual side of it)
  scene = pbNewBattleScene
  # Create the battle class (the mechanics side of it)
  battle = PokeBattle_Battle.new(scene,playerParty,foeParty,playerTrainers,nil)
  battle.party1starts = playerPartyStarts
  # Set various other properties in the battle class
  pbPrepareBattle(battle)
  $PokemonTemp.clearBattleRules
  # Perform the battle itself
  decision = 0
  pbBattleAnimation(pbGetWildBattleBGM(foeParty),(foeParty.length==1) ? 0 : 2,foeParty) {
    pbSceneStandby {
                    decision = battle.pbStartBattle
                   }
  pbAfterBattle(decision,canLose)
  }
  Input.update
  # Save the result of the battle in a Game Variable (1 by default)
  #    0 - Undecided or aborted
  #    1 - Player won
  #    2 - Player lost
  #    3 - Player or wild Pokémon ran from battle, or player forfeited the match
  #    4 - Wild Pokémon was caught
  #    5 - Draw
  pbSet(outcomeVar,decision)
  rewards = $PokemonTemp&.battleRewards || []

  # No rewards for losing
  if rewards.is_a?(Array) && rewards.length > 0 && [1, 4].include?(decision)
    rewards.each do |key, value|
      case key
      when "money" then
        amount = value.to_i
        $Trainer.money += amount if amount.positive?
        if amount>0
          pbMessage(_INTL("You got ${1} for winning!", amount.to_s_formatted))
        end

      when "item" then
        pbReceiveItem(value)
      end
    end
  end

  $PokemonTemp.battleRewards = nil
  return decision
end

# alpha icon ---
class PokemonDataBox < SpriteWrapper
  def refresh
    self.bitmap.clear
    return if !@battler.pokemon
    textPos = []
    imagePos = []
    # Draw background panel
    self.bitmap.blt(0,0,@databoxBitmap.bitmap,Rect.new(0,0,@databoxBitmap.width,@databoxBitmap.height))
    # Draw Pokémon's name
    nameWidth = self.bitmap.text_size(@battler.name).width
    nameOffset = 0
    nameOffset = nameWidth-116 if nameWidth>116
    textPos.push([@battler.name,@spriteBaseX+8-nameOffset,0,false,NAME_BASE_COLOR,NAME_SHADOW_COLOR])
    # Draw Pokémon's gender symbol
    #KurayNewSymbolGender
    kuraygender1t = "♂"
    kuraygender2t = "♀"
    # kuraygender3t = "♃"
    # kuraygender4t = "♄"
    kuraygender1r = [55, 148, 229]
    kuraygender1s = [68, 98, 125]
    kuraygender2r = [229, 55, 203]
    kuraygender2s = [137, 73, 127]
    # kuraygender3r = [55, 229, 81]
    # kuraygender3s = [68, 127, 76]
    # kuraygender4r = [229, 127, 55]
    # kuraygender4s = [135, 95, 69]
    if @battler.displayGenderPizza
      imagePos.push(["Graphics/Pictures/Storage/gender4", @spriteBaseX+126-18, 5])
      # textPos.push([_INTL(kuraygender4t), @spriteBaseX+126, 0, false, Color.new(kuraygender4r[0], kuraygender4r[1], kuraygender4r[2]), Color.new(kuraygender4s[0], kuraygender4s[1], kuraygender4s[2])])
    else
      case @battler.displayGender
      when 0   # Male
        textPos.push([_INTL(kuraygender1t), @spriteBaseX+126, 0, false, Color.new(kuraygender1r[0], kuraygender1r[1], kuraygender1r[2]), Color.new(kuraygender1s[0], kuraygender1s[1], kuraygender1s[2])])
      when 1   # Female
        textPos.push([_INTL(kuraygender2t), @spriteBaseX+126, 0, false, Color.new(kuraygender2r[0], kuraygender2r[1], kuraygender2r[2]), Color.new(kuraygender2s[0], kuraygender2s[1], kuraygender2s[2])])
      when 2  # Genderless
        imagePos.push(["Graphics/Pictures/Storage/gender3", @spriteBaseX+126-14, 14])
        # textPos.push([_INTL(kuraygender3t), @spriteBaseX+126, 0, false, Color.new(kuraygender3r[0], kuraygender3r[1], kuraygender3r[2]), Color.new(kuraygender3s[0], kuraygender3s[1], kuraygender3s[2])])
      end
    end
    pbDrawTextPositions(self.bitmap,textPos)
    # Draw Pokémon's level
    show_level = true
    if $game_switches[SWITCH_NO_LEVELS_MODE] && ($PokemonSystem.showlevel_nolevelmode && $PokemonSystem.showlevel_nolevelmode == 0)
      show_level = false
    end
    imagePos.push(["Graphics/Pictures/Battle/overlay_lv",@spriteBaseX+140,16]) if show_level
    pbDrawNumber(@battler.level,self.bitmap,@spriteBaseX+162,16) if show_level
    # Draw shiny icon
    if @battler.shiny? || @battler.fakeshiny?
      shinyX = (@battler.opposes?(0)) ? 206 : -6   # Foe's/player's
      #KurayX
      # pokeRadarShiny= !@battler.pokemon.debugShiny? && !@battler.pokemon.naturalShiny?
      #KurayX new ShinyStars
      shinyY = 35
      if $PokemonSystem.typedisplay != 0 #Trapstarr - Reposition shiny star if type display is on
        shinyX = (@battler.opposes?(0)) ? -8 : -6 # Foe's/player's (Left of Nameplate)
        shinyY = 13
      end
      addShinyStarsToGraphicsArray(imagePos,@spriteBaseX+shinyX,shinyY, @battler.pokemon.bodyShiny?,@battler.pokemon.headShiny?,@battler.pokemon.debugShiny?,nil,nil,nil,nil,false,false,@battler.pokemon.fakeshiny?,[@battler.pokemon.shinyR?,@battler.pokemon.shinyG?,@battler.pokemon.shinyB?,@battler.pokemon.shinyKRS?])
    end
    if @battler.alpha?

      imagePos.push([sprintf("Graphics/Pictures/alpha"), @spriteBaseX+126-48,5])
    end
    # Draw Mega Evolution/Primal Reversion icon
    if @battler.mega?
      imagePos.push(["Graphics/Pictures/Battle/icon_mega",@spriteBaseX+8,34])
    elsif @battler.primal?
      primalX = (@battler.opposes?) ? 208 : -28   # Foe's/player's
      if @battler.isSpecies?(:KYOGRE)
        imagePos.push(["Graphics/Pictures/Battle/icon_primal_Kyogre",@spriteBaseX+primalX,4])
      elsif @battler.isSpecies?(:GROUDON)
        imagePos.push(["Graphics/Pictures/Battle/icon_primal_Groudon",@spriteBaseX+primalX,4])
      end
    end
    # Draw owned icon (foe Pokémon only)
    if @battler.owned? && @battler.opposes?(0)
      imagePos.push(["Graphics/Pictures/Battle/icon_own",@spriteBaseX-8,42])
    end
    # Draw status icon
    # if @battler.status != :NONE
    #   s = GameData::Status.get(@battler.status).id_number
    #   if s == :POISON && @battler.statusCount > 0   # Badly poisoned
    #     s = GameData::Status::DATA.keys.length / 2
    #   end
    #   imagePos.push(["Graphics/Pictures/Battle/icon_statuses",@spriteBaseX+24,56,
    #                  0,(s-1)*STATUS_ICON_HEIGHT,-1,STATUS_ICON_HEIGHT])
    # end
    pbDrawImagePositions(self.bitmap,imagePos)
    refreshHP
    refreshExp
    refreshStatus
    # Trapstarr's Type Display
    if $PokemonSystem.typedisplay != 0 && $PokemonSystem.typedisplay != nil
      refreshtypeDisplay
    end
  end
end
class PokemonStorageScene
  def pbUpdateOverlay(selection, party = nil)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    buttonbase = Color.new(248, 248, 248)
    buttonshadow = Color.new(80, 80, 80)
    pbDrawTextPositions(overlay, [
                                  [_INTL("Party: {1}", (@storage.party.length rescue 0)), 270, 326, 2, buttonbase, buttonshadow, 1],
                                  [_INTL("Exit"), 446, 326, 2, buttonbase, buttonshadow, 1],
                                  ])
    pokemon = nil
    if @screen.pbHolding? && !@screen.fusionMode
      pokemon = @screen.pbHeldPokemon
    elsif selection >= 0
      pokemon = (party) ? party[selection] : @storage[@storage.currentBox, selection]
    end
    if !pokemon
      @sprites["pokemon"].visible = false
      return
    end
    @sprites["pokemon"].visible = true
    base = Color.new(88, 88, 80)
    shadow = Color.new(168, 184, 184)
    nonbase = Color.new(208, 208, 208)
    nonshadow = Color.new(224, 224, 224)
    pokename = pokemon.name
    textstrings = [
      [pokename, 10, 2, false, base, shadow]
    ]
    if !pokemon.egg?
      imagepos = []
      #KurayNewSymbolGender
      kuraygender1t = "♂"
      kuraygender2t = "♀"
      # kuraygender3t = "♃"
      # kuraygender4t = "♄"
      kuraygender1r = [55, 148, 229]
      kuraygender1s = [68, 98, 125]
      kuraygender2r = [229, 55, 203]
      kuraygender2s = [137, 73, 127]
      # kuraygender3r = [55, 229, 81]
      # kuraygender3s = [68, 127, 76]
      # kuraygender4r = [229, 127, 55]
      # kuraygender4s = [135, 95, 69]
      if pokemon.pizza?
        imagepos.push(["Graphics/Pictures/Storage/gender4", 136, 9])
        # textstrings.push([_INTL(kuraygender4t), 148, 2, false, Color.new(kuraygender4r[0], kuraygender4r[1], kuraygender4r[2]), Color.new(kuraygender4s[0], kuraygender4s[1], kuraygender4s[2])])
      elsif pokemon.male?
        textstrings.push([_INTL(kuraygender1t), 148, 2, false, Color.new(kuraygender1r[0], kuraygender1r[1], kuraygender1r[2]), Color.new(kuraygender1s[0], kuraygender1s[1], kuraygender1s[2])])
      elsif pokemon.female?
        textstrings.push([_INTL(kuraygender2t), 148, 2, false, Color.new(kuraygender2r[0], kuraygender2r[1], kuraygender2r[2]), Color.new(kuraygender2s[0], kuraygender2s[1], kuraygender2s[2])])
      elsif pokemon.genderless?
        imagepos.push(["Graphics/Pictures/Storage/gender3", 136, 15])
        # textstrings.push([_INTL(kuraygender3t), 148, 2, false, Color.new(kuraygender3r[0], kuraygender3r[1], kuraygender3r[2]), Color.new(kuraygender3s[0], kuraygender3s[1], kuraygender3s[2])])
      end
      imagepos.push(["Graphics/Pictures/Storage/overlay_lv", 6, 246])
      textstrings.push([pokemon.level.to_s, 28, 228, false, base, shadow])
      if pokemon.ability
        textstrings.push([pokemon.ability.name, 86, 300, 2, base, shadow])
      else
        textstrings.push([_INTL("No ability"), 86, 300, 2, nonbase, nonshadow])
      end
      if pokemon.item
        textstrings.push([pokemon.item.name, 86, 336, 2, base, shadow])
      else
        textstrings.push([_INTL("No item"), 86, 336, 2, nonbase, nonshadow])
      end
      if pokemon.shiny? || pokemon.fakeshiny?
        #KurayX new ShinyStars
        addShinyStarsToGraphicsArray(imagepos,156,198,pokemon.bodyShiny?,pokemon.headShiny?,pokemon.debugShiny?,nil,nil,nil,nil,false,true,pokemon.fakeshiny?,[pokemon.shinyR?,pokemon.shinyG?,pokemon.shinyB?,pokemon.shinyKRS?])
        #imagepos.push(["Graphics/Pictures/shiny", 156, 198])
      end
      if pokemon.alpha?

        imagepos.push([sprintf("Graphics/Pictures/alpha"),  160, 198])
      end
      typebitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/types"))
      type1_number = GameData::Type.get(pokemon.type1).id_number
      type2_number = GameData::Type.get(pokemon.type2).id_number
      type1rect = Rect.new(0, type1_number * 28, 64, 28)
      type2rect = Rect.new(0, type2_number * 28, 64, 28)
      if pokemon.type1 == pokemon.type2
        overlay.blt(52, 272, typebitmap.bitmap, type1rect)
      else
        overlay.blt(18, 272, typebitmap.bitmap, type1rect)
        overlay.blt(88, 272, typebitmap.bitmap, type2rect)
      end
      drawMarkings(overlay, 70, 240, 128, 20, pokemon.markings)
      pbDrawImagePositions(overlay, imagepos)
    end
    pbDrawTextPositions(overlay, textstrings)
    @sprites["pokemon"].setPokemonBitmap(pokemon)

    if pokemon.egg?
      @sprites["pokemon"].zoom_x = Settings::EGGSPRITE_SCALE
      @sprites["pokemon"].zoom_y = Settings::EGGSPRITE_SCALE
    else
      @sprites["pokemon"].zoom_x = Settings::FRONTSPRITE_SCALE
      @sprites["pokemon"].zoom_y = Settings::FRONTSPRITE_SCALE
    end

  end
end
class PokemonPartyPanel < SpriteWrapper
  def refresh
    return if disposed?
    return if @refreshing
    @refreshing = true
    if @panelbgsprite && !@panelbgsprite.disposed?
      if self.selected
        if self.preselected;
          @panelbgsprite.changeBitmap("swapsel2")
        elsif @switching;
          @panelbgsprite.changeBitmap("swapsel")
        elsif @pokemon.fainted?;
          @panelbgsprite.changeBitmap("faintedsel")
        else
          ; @panelbgsprite.changeBitmap("ablesel")
        end
      else
        if self.preselected;
          @panelbgsprite.changeBitmap("swap")
        elsif @pokemon.fainted?;
          @panelbgsprite.changeBitmap("fainted")
        else
          ; @panelbgsprite.changeBitmap("able")
        end
      end
      @panelbgsprite.x = self.x
      @panelbgsprite.y = self.y
      @panelbgsprite.color = self.color
    end
    if @hpbgsprite && !@hpbgsprite.disposed?
      @hpbgsprite.visible = (!@pokemon.egg? && !(@text && @text.length > 0))
      if @hpbgsprite.visible
        if self.preselected || (self.selected && @switching);
          @hpbgsprite.changeBitmap("swap")
        elsif @pokemon.fainted?;
          @hpbgsprite.changeBitmap("fainted")
        else
          ; @hpbgsprite.changeBitmap("able")
        end
        @hpbgsprite.x = self.x + 96
        @hpbgsprite.y = self.y + 50
        @hpbgsprite.color = self.color
      end
    end
    if @ballsprite && !@ballsprite.disposed?
      @ballsprite.changeBitmap((self.selected) ? "sel" : "desel")
      @ballsprite.x = self.x + 10
      @ballsprite.y = self.y
      @ballsprite.color = self.color
    end
    if @pkmnsprite && !@pkmnsprite.disposed?
      @pkmnsprite.x = self.x + 60
      @pkmnsprite.y = self.y + 40
      @pkmnsprite.color = self.color
      @pkmnsprite.selected = self.selected
    end
    if @helditemsprite && !@helditemsprite.disposed?
      if @helditemsprite.visible
        @helditemsprite.x = self.x + 62
        @helditemsprite.y = self.y + 48
        @helditemsprite.color = self.color
      end
    end
    if @overlaysprite && !@overlaysprite.disposed?
      @overlaysprite.x = self.x
      @overlaysprite.y = self.y
      @overlaysprite.color = self.color
    end
    if @refreshBitmap
      @refreshBitmap = false
      @overlaysprite.bitmap.clear if @overlaysprite.bitmap
      basecolor = Color.new(248, 248, 248)
      shadowcolor = Color.new(40, 40, 40)
      pbSetSystemFont(@overlaysprite.bitmap)
      textpos = []
      # Draw Pokémon name
      textpos.push([@pokemon.name, 96, 10, 0, basecolor, shadowcolor])
      if !@pokemon.egg?
        if !@text || @text.length == 0
          # Draw HP numbers
          textpos.push([sprintf("% 3d /% 3d", @pokemon.hp, @pokemon.totalhp), 224, 54, 1, basecolor, shadowcolor])
          # Draw HP bar
          if @pokemon.hp > 0
            w = @pokemon.hp * 96 * 1.0 / @pokemon.totalhp
            w = 1 if w < 1
            w = ((w / 2).round) * 2
            hpzone = 0
            hpzone = 1 if @pokemon.hp <= (@pokemon.totalhp / 2).floor
            hpzone = 2 if @pokemon.hp <= (@pokemon.totalhp / 4).floor
            hprect = Rect.new(0, hpzone * 8, w, 8)
            @overlaysprite.bitmap.blt(128, 52, @hpbar.bitmap, hprect)
          end
          # Draw status
          status = 0
          if @pokemon.fainted?
            status = GameData::Status::DATA.keys.length / 2
          elsif @pokemon.status != :NONE
            status = GameData::Status.get(@pokemon.status).id_number
          elsif @pokemon.pokerusStage == 1
            status = GameData::Status::DATA.keys.length / 2 + 1
          end
          status -= 1
          if status >= 0
            statusrect = Rect.new(0, 16 * status, 44, 16)
            @overlaysprite.bitmap.blt(78, 68, @statuses.bitmap, statusrect)
          end
        end
        # Draw gender symbol
        #KurayNewSymbolGender
        imagePos = []
        kuraygender1t = "♂"
        kuraygender2t = "♀"
        # kuraygender3t = "♃"
        # kuraygender4t = "♄"
        kuraygender1r = [55, 148, 229]
        kuraygender1s = [68, 98, 125]
        kuraygender2r = [229, 55, 203]
        kuraygender2s = [137, 73, 127]
        # kuraygender3r = [55, 229, 81]
        # kuraygender3s = [68, 127, 76]
        # kuraygender4r = [229, 127, 55]
        # kuraygender4s = [135, 95, 69]
        if @pokemon.pizza?
          imagePos.push(["Graphics/Pictures/Storage/gender4", 206, 15])
          # textpos.push([_INTL(kuraygender4t), 224, 10, 0, Color.new(kuraygender4r[0], kuraygender4r[1], kuraygender4r[2]), Color.new(kuraygender4s[0], kuraygender4s[1], kuraygender4s[2])])
        elsif @pokemon.male?
          textpos.push([_INTL(kuraygender1t), 224, 10, 0, Color.new(kuraygender1r[0], kuraygender1r[1], kuraygender1r[2]), Color.new(kuraygender1s[0], kuraygender1s[1], kuraygender1s[2])])
        elsif @pokemon.female?
          textpos.push([_INTL(kuraygender2t), 224, 10, 0, Color.new(kuraygender2r[0], kuraygender2r[1], kuraygender2r[2]), Color.new(kuraygender2s[0], kuraygender2s[1], kuraygender2s[2])])
        elsif @pokemon.genderless?
          imagePos.push(["Graphics/Pictures/Storage/gender3", 210, 24])
          # textpos.push([_INTL(kuraygender3t), 224, 10, 0, Color.new(kuraygender3r[0], kuraygender3r[1], kuraygender3r[2]), Color.new(kuraygender3s[0], kuraygender3s[1], kuraygender3s[2])])
        end
        # Draw shiny icon
        if @pokemon.shiny? || @pokemon.fakeshiny?
          # imagePos=[]
          #KurayX new ShinyStars
          addShinyStarsToGraphicsArray(imagePos,80,48,@pokemon.bodyShiny?,@pokemon.headShiny?,@pokemon.debugShiny?,0,0,16,16,false,false,@pokemon.fakeshiny?,[@pokemon.shinyR?,@pokemon.shinyG?,@pokemon.shinyB?,@pokemon.shinyKRS?])
          # pbDrawImagePositions(@overlaysprite.bitmap,imagePos)
        end
        if @pokemon.alpha?

          imagePos.push([sprintf("Graphics/Pictures/alpha"),  195, 15])
        end
        if imagePos
          pbDrawImagePositions(@overlaysprite.bitmap,imagePos)
        end
      end
      pbDrawTextPositions(@overlaysprite.bitmap, textpos)
      # Draw level text
      if !@pokemon.egg?
        pbDrawImagePositions(@overlaysprite.bitmap, [[
                                                      "Graphics/Pictures/Party/overlay_lv", 20, 70, 0, 0, 22, 14]])
        pbSetSmallFont(@overlaysprite.bitmap)
        pbDrawTextPositions(@overlaysprite.bitmap, [
                                                    [@pokemon.level.to_s, 42, 57, 0, basecolor, shadowcolor]
                                                   ])
      end
      # Draw annotation text
      if @text && @text.length > 0
        pbSetSystemFont(@overlaysprite.bitmap)
        pbDrawTextPositions(@overlaysprite.bitmap, [
                                                    [@text, 96, 52, 0, basecolor, shadowcolor]
                                                   ])
      end
    end
    @refreshing = false
  end
end
class PokemonSummary_Scene
  alias originaldrawpage drawPage
    def drawPage(page)
    if @pokemon.egg?
      drawPageOneEgg
      return
    end
    @sprites["itemicon"].item = @pokemon.item_id
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    base = Color.new(248, 248, 248)
    shadow = Color.new(104, 104, 104)
    # Set background image
    @sprites["background"].setBitmap("Graphics/Pictures/Summary/bg_#{page}") if page < NB_PAGES
    imagepos = []
    # Show the Poké Ball containing the Pokémon
    ballimage = sprintf("Graphics/Pictures/Summary/icon_ball_%s", @pokemon.poke_ball)
    if !pbResolveBitmap(ballimage)
      ballimage = sprintf("Graphics/Pictures/Summary/icon_ball_%02d", pbGetBallType(@pokemon.poke_ball))
    end
    imagepos.push([ballimage, 14, 60])
    # Show status/fainted/Pokérus infected icon
    status = 0
    if @pokemon.fainted?
      status = GameData::Status::DATA.keys.length / 2
    elsif @pokemon.status != :NONE
      status = GameData::Status.get(@pokemon.status).id_number
    elsif @pokemon.pokerusStage == 1
      status = GameData::Status::DATA.keys.length / 2 + 1
    end
    status -= 1
    if status >= 0
      imagepos.push(["Graphics/Pictures/statuses", 124, 100, 0, 16 * status, 44, 16])
    end
    # Show Pokérus cured icon
    if @pokemon.pokerusStage == 2
      imagepos.push([sprintf("Graphics/Pictures/Summary/icon_pokerus"), 176, 100])
    end
    # Show shininess star
    if @pokemon.shiny? || @pokemon.fakeshiny?
      #KurayX new ShinyStars
      addShinyStarsToGraphicsArray(imagepos,2,134,@pokemon.bodyShiny?,@pokemon.headShiny?,@pokemon.debugShiny?,nil,nil,nil,nil,true,false,@pokemon.fakeshiny?,[@pokemon.shinyR?,@pokemon.shinyG?,@pokemon.shinyB?,@pokemon.shinyKRS?])
      #imagepos.push([sprintf("Graphics/Pictures/shiny"), 2, 134])
    end
    if @pokemon.alpha?

      imagepos.push([sprintf("Graphics/Pictures/alpha"), 2, 164])
    end

    # Draw all images
    # pbDrawImagePositions(overlay, imagepos)
    # Write various bits of text
    pagename = [_INTL("INFO"),
                _INTL("TRAINER MEMO"),
                _INTL("SKILLS"),
                _INTL("MOVES"),
                _INTL("MOVES")][page - 1]
    textpos = [
      [pagename, 26, 10, 0, base, shadow],
      [@pokemon.name, 46, 56, 0, base, shadow],
      [@pokemon.level.to_s, 46, 86, 0, Color.new(64, 64, 64), Color.new(176, 176, 176)],
      [_INTL("Item"), 66, 312, 0, base, shadow]
    ]
    # Write the held item's name
    if @pokemon.hasItem?
      textpos.push([@pokemon.item.name, 16, 346, 0, Color.new(64, 64, 64), Color.new(176, 176, 176)])
    else
      textpos.push([_INTL("None"), 16, 346, 0, Color.new(192, 200, 208), Color.new(208, 216, 224)])
    end
    # Write the gender symbol
    #KurayNewSymbolGender
    kuraygender1t = "♂"
    kuraygender2t = "♀"
    # kuraygender3t = "♃"
    # kuraygender4t = "♄"
    kuraygender1r = [55, 148, 229]
    kuraygender1s = [68, 98, 125]
    kuraygender2r = [229, 55, 203]
    kuraygender2s = [137, 73, 127]
    # kuraygender3r = [55, 229, 81]
    # kuraygender3s = [68, 127, 76]
    # kuraygender4r = [229, 127, 55]
    # kuraygender4s = [135, 95, 69]
    if @pokemon.pizza?
      imagepos.push(["Graphics/Pictures/Storage/gender4", 160, 61])
      # textpos.push([_INTL(kuraygender4t), 178, 56, 0, Color.new(kuraygender4r[0], kuraygender4r[1], kuraygender4r[2]), Color.new(kuraygender4s[0], kuraygender4s[1], kuraygender4s[2])])
    elsif @pokemon.male?
      textpos.push([_INTL(kuraygender1t), 178, 56, 0, Color.new(kuraygender1r[0], kuraygender1r[1], kuraygender1r[2]), Color.new(kuraygender1s[0], kuraygender1s[1], kuraygender1s[2])])
    elsif @pokemon.female?
      textpos.push([_INTL(kuraygender2t), 178, 56, 0, Color.new(kuraygender2r[0], kuraygender2r[1], kuraygender2r[2]), Color.new(kuraygender2s[0], kuraygender2s[1], kuraygender2s[2])])
    elsif @pokemon.genderless?
      imagepos.push(["Graphics/Pictures/Storage/gender3", 164, 69])
      # textpos.push([_INTL(kuraygender3t), 178, 56, 0, Color.new(kuraygender3r[0], kuraygender3r[1], kuraygender3r[2]), Color.new(kuraygender3s[0], kuraygender3s[1], kuraygender3s[2])])
    end
    # Draw all text
    pbDrawTextPositions(overlay, textpos)
    pbDrawImagePositions(overlay, imagepos)
    # Draw the Pokémon's markings
    drawMarkings(overlay, 84, 292)
    # Draw page-specific information
    case page
    when 1 then
      drawPageOne
    when 2 then
      drawPageTwo
    when 3 then
      drawPageThree
    when 4 then
      drawPageFour
    when 5 then
      drawPageFive
    end
  end
end
# ---

# alpha variable ---
class Pokemon
  attr_accessor :body_alpha

  attr_accessor :head_alpha

  attr_accessor :alpha

  def alpha?

    if body_alpha == true or head_alpha == true or alpha == true

      return true
    end
    return false

  end
end

class PBFusion

  def pbFusionScreen(cancancel = false, superSplicer = false, firstOptionSelected = false)
    metaplayer1 = SpriteMetafilePlayer.new(@metafile1, @sprites["rsprite1"])
    metaplayer2 = SpriteMetafilePlayer.new(@metafile2, @sprites["rsprite2"])
    metaplayer3 = SpriteMetafilePlayer.new(@metafile3, @sprites["rsprite3"])
    metaplayer4 = SpriteMetafilePlayer.new(@metafile4, @sprites["dnasplicer"])

    metaplayer1.play
    metaplayer2.play
    metaplayer3.play
    metaplayer4.play

    pbBGMStop()
    pbPlayCry(@pokemon)
    Kernel.pbMessageDisplay(@sprites["msgwindow"],
                            _INTL("The Pokémon are being fused!", @pokemon1.name))

    Kernel.pbMessageWaitForInput(@sprites["msgwindow"], 100, true)
    pbPlayDecisionSE()
    oldstate = pbSaveSpriteState(@sprites["rsprite1"])
    oldstate2 = pbSaveSpriteState(@sprites["rsprite2"])
    oldstate3 = pbSaveSpriteState(@sprites["rsprite3"])

    pbBGMPlay("fusion")

    canceled = false
    noMoves = false
    begin
      metaplayer1.update
      metaplayer2.update
      metaplayer3.update
      metaplayer4.update

      Graphics.update
      Input.update
      if Input.trigger?(Input::B) && Input.trigger?(Input::C) # && Input.trigger?(Input::A)# && cancancel
        noMoves = true
        pbSEPlay("buzzer")
        Graphics.update
      end
    end while metaplayer1.playing? && metaplayer2.playing?
    if canceled
      pbBGMStop()
      pbPlayCancelSE()
      # Kernel.pbMessageDisplay(@sprites["msgwindow"],
      @pbEndScreen
      _INTL("Huh? The fusion was cancelled!")
    else
      frames = pbCryFrameLength(@newspecies)
      pbBGMStop()
      pbPlayCry(@newspecies)
      frames.times do
        Graphics.update
      end
      # pbMEPlay("Voltorb Flip Win")
      newSpecies = GameData::Species.get(@newspecies)
      newspeciesname = newSpecies.real_name
      oldspeciesname = GameData::Species.get(@pokemon1.species).real_name

      overlay = BitmapSprite.new(Graphics.width, Graphics.height, @viewport).bitmap

      sprite_bitmap = @sprites["rsprite2"].getBitmap
      # drawSpriteCredits(sprite_bitmap.filename, sprite_bitmap.path, @viewport)
      pbBGMPlay(pbGetWildVictoryME)
      Kernel.pbMessageDisplay(@sprites["msgwindow"],
                              _INTL("\\se[]Congratulations! Your Pokémon were fused into {2}!\\wt[80]", @pokemon1.name, newspeciesname))


      #exp
      @pokemon1.head_gender = @pokemon2.gender
      @pokemon1.head_nickname = @pokemon2.nicknamed?
      @pokemon1.exp_when_fused_head = @pokemon2.exp
      @pokemon1.exp_when_fused_body = @pokemon1.exp
      @pokemon1.exp_gained_since_fused = 0
      @pokemon1.kuray_no_evo = 0
      @pokemon1.kuraycustomfile = nil
      @pokemon2.kuraycustomfile = nil

      # 2 = head
      # 1 = body
      if @pokemon2.item != nil && $PokemonBag.pbCanStore?(@pokemon2.item, 1)
        $PokemonBag.pbStoreItem(@pokemon2.item, 1)
      end
      #KurayX - KURAYX_ABOUT_SHINIES
      if @pokemon2.alpha == true
        @pokemon1.head_alpha = true
      end
      if @pokemon1.alpha == true
        @pokemon1.body_alpha = true
      end


      if @pokemon2.shiny?
        @pokemon1.head_shiny = true
        @pokemon1.head_shinyhue = @pokemon2.shinyValue?
        @pokemon1.head_shinyimprovpif = @pokemon2.shinyimprovpif?
        @pokemon1.head_shinyr = @pokemon2.shinyR?
        @pokemon1.head_shinyg = @pokemon2.shinyG?
        @pokemon1.head_shinyb = @pokemon2.shinyB?
        @pokemon1.head_shinykrs = @pokemon2.shinyKRS?.clone
        if $PokemonSystem.shinyfusedye == 1
          @pokemon1.shinyR = @pokemon2.shinyR?
          @pokemon1.shinyG = @pokemon2.shinyG?
          @pokemon1.shinyB = @pokemon2.shinyB?
          @pokemon1.shinyValue = @pokemon2.shinyValue?
          @pokemon1.shinyKRS = @pokemon2.shinyKRS?.clone
          @pokemon1.shinyimprovpif = @pokemon2.shinyimprovpif?
        end
        # if $PokemonSystem.shinyfusedye == 1 || !@pokemon1.shiny?
        #   @pokemon1.shinyR = @pokemon2.shinyR?
        #   @pokemon1.shinyG = @pokemon2.shinyG?
        #   @pokemon1.shinyB = @pokemon2.shinyB?
        #   @pokemon1.shinyValue = @pokemon2.shinyValue?
        #   @pokemon1.shinyKRS = @pokemon2.shinyKRS?.clone
        # end
      end
      if @pokemon1.shiny?
        @pokemon1.body_shiny = true
        @pokemon1.body_shinyhue = @pokemon1.shinyValue?
        @pokemon1.body_shinyimprovpif = @pokemon1.shinyimprovpif?
        @pokemon1.body_shinyr = @pokemon1.shinyR?
        @pokemon1.body_shinyg = @pokemon1.shinyG?
        @pokemon1.body_shinyb = @pokemon1.shinyB?
        @pokemon1.body_shinykrs = @pokemon1.shinyKRS?.clone
      end
      if @pokemon2.shiny? && @pokemon1.shiny? && $PokemonSystem.shinyfusedye == 0
        @pokemon1.shinyR = @pokemon2.shinyR?
        @pokemon1.shinyG = @pokemon2.shinyG?
        @pokemon1.shinyB = @pokemon2.shinyB?
        @pokemon1.shinyValue = @pokemon2.shinyValue?
        @pokemon1.shinyKRS = @pokemon2.shinyKRS?.clone
        @pokemon1.shinyimprovpif = @pokemon2.shinyimprovpif?
      end
      if $PokemonSystem.shinyfusedye == 2
        @pokemon1.shinyimprovpif = rollimproveshiny()
        @pokemon1.head_shinyimprovpif = rollimproveshiny()
        @pokemon1.body_shinyimprovpif = rollimproveshiny()
        @pokemon1.shinyValue = rand(0..360) - 180
        @pokemon1.shinyR = kurayRNGforChannels
        @pokemon1.shinyG = kurayRNGforChannels
        @pokemon1.shinyB = kurayRNGforChannels
        @pokemon1.shinyKRS = kurayKRSmake
        @pokemon1.body_shinyhue = rand(0..360) - 180
        @pokemon1.body_shinyr = kurayRNGforChannels
        @pokemon1.body_shinyg = kurayRNGforChannels
        @pokemon1.body_shinyb = kurayRNGforChannels
        @pokemon1.body_shinykrs = kurayKRSmake
        @pokemon1.head_shinyhue = rand(0..360) - 180
        @pokemon1.head_shinyr = kurayRNGforChannels
        @pokemon1.head_shinyg = kurayRNGforChannels
        @pokemon1.head_shinyb = kurayRNGforChannels
      end
    end

end
end
class PokemonTemp
  attr_accessor :encounterIsAlphaPokemon
end

class PokeBattle_Battler

  def alpha?
    if @pokemon
      return @pokemon.alpha?
    end
  return false
  end
end
module BallHandlers

  def self.onCatch(ball,battle,pkmn)
    pkmn.item=(nil)if pkmn.alpha? == true
    OnCatch.trigger(ball,battle,pkmn)
  end
end


module PokeBattle_BattleCommon
  alias originalCaptureCalc pbCaptureCalc

  def pbCaptureCalc(pkmn, battler, catch_rate, ball)
    if pkmn.alpha? and catch_rate != nil
      catch_rate *= 0.8
    end
    return originalCaptureCalc(pkmn, battler, catch_rate, ball) 
  end
end



ALL_MOVES =
 [[:BUG, :MEGAHORN], [:BUG, :ATTACKORDER], [:BUG, :BUGBUZZ], [:BUG, :FIRSTIMPRESSION], [:BUG, :POLLENPUFF], [:BUG, :LEECHLIFE], [:BUG, :LUNGE], [:BUG, :XSCISSOR], [:BUG, :SIGNALBEAM], [:BUG,   :UTURN], [:BUG, :STEAMROLLER], [:BUG, :BUGBITE], [:BUG, :SILVERWIND], [:BUG, :FELLSTINGER],

  [:BUG, :STRUGGLEBUG], [:BUG, :FURYCUTTER], [:BUG, :PINMISSILE], [:BUG, :TWINEEDLE], [:BUG, :INFESTATION], [:BUG, :DEFENDORDER], [:BUG, :HEALORDER], [:BUG, :POWDER], [:BUG, :QUIVERDANCE], [:BUG, :RAGEPOWDER],
  [:BUG, :SPIDERWEB], [:BUG, :STICKYWEB], [:BUG, :STRINGSHOT], [:BUG, :TAILGLOW], [:DARK, :HYPERSPACEFURY], [:DARK, :FOULPLAY], [:DARK,  :DARKESTLARIAT], [:DARK, :NIGHTDAZE], [:DARK, :CRUNCH], [:DARK, :DARKPULSE], [:DARK, :THROATCHOP], [:DARK, :NIGHTSLASH], [:DARK, :SUCKERPUNCH], [:DARK, :KNOCKOFF], [:DARK, :ASSURANCE], [:DARK, :BITE], [:DARK, :BRUTALSWING],
  [:DARK, :FEINTATTACK], [:DARK, :THIEF], [:DARK, :SNARL], [:DARK, :PAYBACK], [:DARK, :PURSUIT], [:DARK, :BEATUP],
  [:DARK, :FLING], [:DARK, :POWERTRIP], [:DARK, :PUNISHMENT], [:DARK, :DARKVOID], [:DARK, :EMBARGO], [:DARK, :FAKETEARS], [:DARK, :FLATTER], [:DARK, :HONECLAWS], [:DARK, :MEMENTO], [:DARK, :NASTYPLOT], [:DARK, :PARTINGSHOT], [:DARK, :QUASH], [:DARK, :SNATCH], [:DARK, :SWITCHEROO], [:DARK, :TAUNT], [:DARK, :TOPSYTURVY], [:DARK, :TORMENT], [:DRAGON, :ROAROFTIME], [:DRAGON, :DRACOMETEOR], [:DRAGON, :OUTRAGE], [:DRAGON, :CLANGINGSCALES], [:DRAGON, :COREENFORCER], [:DRAGON, :DRAGONRUSH], [:DRAGON, :SPACIALREND], [:DRAGON, :DRAGONHAMMER], [:DRAGON, :DRAGONPULSE], [:DRAGON, :DRAGONCLAW], [:DRAGON, :DRAGONBREATH],
  [:DRAGON, :DRAGONTAIL], [:DRAGON, :DUALCHOP], [:DRAGON, :TWISTER], [:DRAGON, :DRAGONRAGE], [:DRAGON, :DRAGONDANCE], [:ELECTRIC, :BOLTSTRIKE], [:ELECTRIC, :VOLTTACKLE], [:ELECTRIC, :ZAPCANNON], [:ELECTRIC, :THUNDER],
  [:ELECTRIC, :FUSIONBOLT], [:ELECTRIC, :PLASMAFISTS], [:ELECTRIC, :THUNDERBOLT], [:ELECTRIC, :WILDCHARGE], [:ELECTRIC, :DISCHARGE], [:ELECTRIC, :ZINGZAP], [:ELECTRIC, :THUNDERPUNCH], [:ELECTRIC, :VOLTSWITCH], [:ELECTRIC, :PARABOLICCHARGE], [:ELECTRIC, :SPARK],
  [:ELECTRIC, :THUNDERFANG], [:ELECTRIC, :SHOCKWAVE], [:ELECTRIC, :ELECTROWEB], [:ELECTRIC, :CHARGEBEAM], [:ELECTRIC, :THUNDERSHOCK], [:ELECTRIC, :NUZZLE], [:ELECTRIC, :ELECTROBALL], [:ELECTRIC, :CHARGE], [:ELECTRIC, :EERIEIMPULSE], [:ELECTRIC, :ELECTRICTERRAIN], [:ELECTRIC, :ELECTRIFY], [:ELECTRIC, :IONDELUGE], [:ELECTRIC, :MAGNETRISE], [:ELECTRIC, :MAGNETICFLUX], [:ELECTRIC, :THUNDERWAVE], [:FAIRY, :LIGHTOFRUIN], [:FAIRY, :FLEURCANNON], [:FAIRY, :MOONBLAST], [:FAIRY, :PLAYROUGH], [:FAIRY, :DAZZLINGGLEAM], [:FAIRY, :DRAININGKISS],
  [:FAIRY, :DISARMINGVOICE], [:FAIRY, :FAIRYWIND],
  [:FAIRY, :NATURESMADNESS], [:FAIRY, :AROMATICMIST], [:FAIRY, :BABYDOLLEYES], [:FAIRY, :CHARM], [:FAIRY, :CRAFTYSHIELD], [:FAIRY, :FAIRYLOCK], [:FAIRY, :FLORALHEALING], [:FAIRY, :FLOWERSHIELD], [:FAIRY, :GEOMANCY], [:FAIRY, :MISTYTERRAIN], [:FAIRY, :MOONLIGHT], [:FAIRY, :SWEETKISS], [:FIGHTING, :FOCUSPUNCH], [:FIGHTING, :HIJUMPKICK], [:FIGHTING, :CLOSECOMBAT], [:FIGHTING, :FOCUSBLAST], [:FIGHTING, :SUPERPOWER], [:FIGHTING, :CROSSCHOP], [:FIGHTING, :DYNAMICPUNCH], [:FIGHTING, :FLYINGPRESS], [:FIGHTING, :HAMMERARM], [:FIGHTING, :JUMPKICK], [:FIGHTING, :SACREDSWORD], [:FIGHTING, :SECRETSWORD], [:FIGHTING, :SKYUPPERCUT], [:FIGHTING, :AURASPHERE],
  [:FIGHTING, :SUBMISSION], [:FIGHTING, :BRICKBREAK], [:FIGHTING, :DRAINPUNCH], [:FIGHTING, :VITALTHROW], [:FIGHTING, :WAKEUPSLAP], [:FIGHTING, :LOWSWEEP], [:FIGHTING, :CIRCLETHROW], [:FIGHTING, :FORCEPALM],
  [:FIGHTING, :REVENGE], [:FIGHTING, :ROLLINGKICK], [:FIGHTING, :STORMTHROW], [:FIGHTING, :KARATECHOP], [:FIGHTING, :MACHPUNCH], [:FIGHTING, :POWERUPPUNCH], [:FIGHTING, :ROCKSMASH], [:FIGHTING, :VACUUMWAVE], [:FIGHTING, :DOUBLEKICK], [:FIGHTING, :ARMTHRUST], [:FIGHTING, :TRIPLEKICK], [:FIGHTING, :COUNTER], [:FIGHTING, :FINALGAMBIT], [:FIGHTING, :LOWKICK], [:FIGHTING, :REVERSAL], [:FIGHTING, :SEISMICTOSS], [:FIGHTING, :BULKUP], [:FIGHTING, :DETECT], [:FIGHTING, :MATBLOCK], [:FIGHTING, :QUICKGUARD], [:FIRE, :VCREATE], [:FIRE, :BLASTBURN], [:FIRE, :ERUPTION], [:FIRE, :MINDBLOWN], [:FIRE, :SHELLTRAP], [:FIRE, :BLUEFLARE], [:FIRE, :BURNUP], [:FIRE, :OVERHEAT], [:FIRE, :FLAREBLITZ], [:FIRE, :FIREBLAST], [:FIRE, :FUSIONFLARE], [:FIRE, :INFERNO], [:FIRE, :MAGMASTORM], [:FIRE, :SACREDFIRE], [:FIRE, :SEARINGSHOT], [:FIRE, :HEATWAVE], [:FIRE, :FLAMETHROWER], [:FIRE, :BLAZEKICK], [:FIRE, :FIERYDANCE], [:FIRE, :FIRELASH], [:FIRE, :FIREPLEDGE], [:FIRE, :LAVAPLUME], [:FIRE, :FIREPUNCH], [:FIRE, :MYSTICALFIRE], [:FIRE, :FLAMEBURST], [:FIRE, :FIREFANG], [:FIRE, :FLAMEWHEEL], [:FIRE, :INCINERATE], [:FIRE, :FLAMECHARGE], [:FIRE, :EMBER], [:FIRE, :FIRESPIN], [:FIRE, :HEATCRASH], [:FIRE, :SUNNYDAY], [:FIRE, :WILLOWISP], [:FLYING, :SKYATTACK], [:FLYING, :BRAVEBIRD], [:FLYING, :DRAGONASCENT], [:FLYING, :HURRICANE], [:FLYING, :AEROBLAST], [:FLYING, :BEAKBLAST], [:FLYING, :FLY], [:FLYING, :BOUNCE], [:FLYING, :DRILLPECK], [:FLYING, :OBLIVIONWING], [:FLYING, :AIRSLASH], [:FLYING, :CHATTER], [:FLYING, :AERIALACE], [:FLYING, :AIRCUTTER], [:FLYING, :PLUCK], [:FLYING, :SKYDROP], [:FLYING, :WINGATTACK], [:FLYING, :ACROBATICS], [:FLYING, :GUST], [:FLYING, :PECK], [:FLYING, :DEFOG], [:FLYING, :FEATHERDANCE], [:FLYING, :MIRRORMOVE], [:FLYING, :ROOST], [:FLYING, :TAILWIND], [:GHOST, :SHADOWFORCE], [:GHOST, :MOONGEISTBEAM], [:GHOST, :PHANTOMFORCE], [:GHOST, :SPECTRALTHIEF], [:GHOST, :SHADOWBONE], [:GHOST, :SHADOWBALL], [:GHOST, :SPIRITSHACKLE], [:GHOST, :SHADOWCLAW], [:GHOST, :HEX], [:GHOST, :OMINOUSWIND], [:GHOST, :SHADOWPUNCH], [:GHOST, :SHADOWSNEAK], [:GHOST, :ASTONISH], [:GHOST, :LICK], [:GHOST, :NIGHTSHADE], [:GHOST, :CONFUSERAY], [:GHOST, :CURSE], [:GHOST, :DESTINYBOND], [:GHOST, :GRUDGE], [:GHOST, :NIGHTMARE], [:GHOST, :SPITE], [:GHOST, :TRICKORTREAT], [:GRASS, :FRENZYPLANT], [:GRASS, :LEAFSTORM], [:GRASS, :SOLARBLADE], [:GRASS, :PETALDANCE], [:GRASS, :POWERWHIP], [:GRASS, :SEEDFLARE], [:GRASS, :SOLARBEAM], [:GRASS, :WOODHAMMER], [:GRASS, :ENERGYBALL], [:GRASS, :LEAFBLADE], [:GRASS, :PETALBLIZZARD], [:GRASS, :GRASSPLEDGE], [:GRASS, :SEEDBOMB], [:GRASS, :GIGADRAIN], [:GRASS, :HORNLEECH], [:GRASS, :TROPKICK], [:GRASS, :LEAFTORNADO], [:GRASS, :MAGICALLEAF], [:GRASS, :NEEDLEARM], [:GRASS, :RAZORLEAF], [:GRASS, :VINEWHIP], [:GRASS, :LEAFAGE], [:GRASS, :MEGADRAIN], [:GRASS, :BULLETSEED], [:GRASS, :ABSORB], [:GRASS, :GRASSKNOT], [:GRASS, :AROMATHERAPY], [:GRASS, :COTTONGUARD], [:GRASS, :COTTONSPORE], [:GRASS, :FORESTSCURSE], [:GRASS, :GRASSWHISTLE], [:GRASS, :GRASSYTERRAIN], [:GRASS, :INGRAIN], [:GRASS, :LEECHSEED], [:GRASS, :SLEEPPOWDER], [:GRASS, :SPIKYSHIELD], [:GRASS, :SPORE], [:GRASS, :STRENGTHSAP], [:GRASS, :STUNSPORE], [:GRASS, :SYNTHESIS], [:GRASS, :WORRYSEED], [:GROUND, :PRECIPICEBLADES], [:GROUND, :EARTHQUAKE], [:GROUND, :HIGHHORSEPOWER], [:GROUND, :EARTHPOWER], [:GROUND, :LANDSWRATH], [:GROUND, :THOUSANDARROWS], [:GROUND, :THOUSANDWAVES], [:GROUND, :DIG], [:GROUND, :DRILLRUN], [:GROUND, :STOMPINGTANTRUM], [:GROUND, :BONECLUB], [:GROUND, :MUDBOMB], [:GROUND, :BULLDOZE], [:GROUND, :MUDSHOT], [:GROUND, :BONEMERANG], [:GROUND, :SANDTOMB], [:GROUND, :BONERUSH], [:GROUND, :MUDSLAP], [:GROUND, :FISSURE], [:GROUND, :MAGNITUDE], [:GROUND, :MUDSPORT], [:GROUND, :ROTOTILLER], [:GROUND, :SANDATTACK], [:GROUND, :SHOREUP],
  [:GROUND, :SPIKES], [:ICE, :FREEZESHOCK], [:ICE, :ICEBURN], [:ICE, :BLIZZARD], [:ICE, :ICEHAMMER], [:ICE, :ICEBEAM], [:ICE, :ICICLECRASH], [:ICE, :ICEPUNCH], [:ICE, :FREEZEDRY], [:ICE, :AURORABEAM], [:ICE, :GLACIATE],
  [:ICE, :ICEFANG], [:ICE, :AVALANCHE], [:ICE, :FROSTBREATH], [:ICE, :ICYWIND], [:ICE, :ICESHARD], [:ICE, :POWDERSNOW], [:ICE, :ICEBALL], [:ICE, :ICICLESPEAR], [:ICE, :SHEERCOLD], [:ICE, :AURORAVEIL], [:ICE, :HAIL], [:ICE, :HAZE], [:ICE, :MIST], [:NORMAL, :EXPLOSION], [:NORMAL, :SELFDESTRUCT], [:NORMAL, :GIGAIMPACT], [:NORMAL, :HYPERBEAM], [:NORMAL, :BOOMBURST], [:NORMAL, :LASTRESORT], [:NORMAL, :SKULLBASH], [:NORMAL, :DOUBLEEDGE], [:NORMAL, :HEADCHARGE], [:NORMAL, :MEGAKICK], [:NORMAL, :TECHNOBLAST], [:NORMAL, :THRASH], [:NORMAL, :EGGBOMB], [:NORMAL, :JUDGMENT], [:NORMAL, :HYPERVOICE], [:NORMAL, :MULTIATTACK], [:NORMAL, :REVELATIONDANCE], [:NORMAL, :ROCKCLIMB], [:NORMAL, :TAKEDOWN], [:NORMAL, :UPROAR], [:NORMAL, :BODYSLAM], [:NORMAL, :EXTREMESPEED], [:NORMAL, :HYPERFANG], [:NORMAL, :MEGAPUNCH], [:NORMAL, :RAZORWIND], [:NORMAL, :SLAM], [:NORMAL, :STRENGTH], [:NORMAL, :TRIATTACK], [:NORMAL, :CRUSHCLAW], [:NORMAL, :RELICSONG], [:NORMAL, :CHIPAWAY], [:NORMAL, :DIZZYPUNCH], [:NORMAL, :FACADE], [:NORMAL, :HEADBUTT], [:NORMAL, :RETALIATE], [:NORMAL, :SECRETPOWER], [:NORMAL, :SLASH], [:NORMAL, :SMELLINGSALT], [:NORMAL, :HORNATTACK], [:NORMAL, :STOMP], [:NORMAL, :COVET], [:NORMAL, :HIDDENPOWER], [:NORMAL, :ROUND], [:NORMAL, :SWIFT], [:NORMAL, :VICEGRIP], [:NORMAL, :CUT], [:NORMAL, :SNORE], [:NORMAL, :STRUGGLE], [:NORMAL, :WEATHERBALL], [:NORMAL, :ECHOEDVOICE], [:NORMAL, :FAKEOUT], [:NORMAL, :FALSESWIPE], [:NORMAL, :HOLDBACK], [:NORMAL, :PAYDAY], [:NORMAL, :POUND], [:NORMAL, :QUICKATTACK], [:NORMAL, :SCRATCH], [:NORMAL, :TACKLE], [:NORMAL, :DOUBLEHIT], [:NORMAL, :FEINT], [:NORMAL, :TAILSLAP], [:NORMAL, :RAGE], [:NORMAL, :RAPIDSPIN], [:NORMAL, :SPIKECANNON], [:NORMAL, :COMETPUNCH], [:NORMAL, :FURYSWIPES], [:NORMAL, :BARRAGE], [:NORMAL, :BIND], [:NORMAL, :DOUBLESLAP], [:NORMAL, :FURYATTACK], [:NORMAL, :WRAP], [:NORMAL, :CONSTRICT], [:NORMAL, :BIDE], [:NORMAL, :CRUSHGRIP], [:NORMAL, :ENDEAVOR], [:NORMAL, :FLAIL], [:NORMAL, :FRUSTRATION], [:NORMAL, :GUILLOTINE], [:NORMAL, :HORNDRILL], [:NORMAL, :NATURALGIFT], [:NORMAL, :PRESENT], [:NORMAL, :RETURN], [:NORMAL, :SONICBOOM], [:NORMAL, :SPITUP], [:NORMAL, :SUPERFANG], [:NORMAL, :TRUMPCARD], [:NORMAL, :WRINGOUT], [:NORMAL, :ACUPRESSURE], [:NORMAL, :AFTERYOU], [:NORMAL, :ASSIST], [:NORMAL, :ATTRACT], [:NORMAL, :BATONPASS], [:NORMAL, :BELLYDRUM], [:NORMAL, :BESTOW], [:NORMAL, :BLOCK], [:NORMAL, :CAMOUFLAGE], [:NORMAL, :CAPTIVATE], [:NORMAL, :CELEBRATE], [:NORMAL, :CONFIDE], [:NORMAL, :CONVERSION], [:NORMAL, :CONVERSION2], [:NORMAL, :COPYCAT], [:NORMAL, :DEFENSECURL], [:NORMAL, :DISABLE], [:NORMAL, :DOUBLETEAM], [:NORMAL, :ENCORE], [:NORMAL, :ENDURE], [:NORMAL, :ENTRAINMENT], [:NORMAL, :FLASH], [:NORMAL, :FOCUSENERGY], [:NORMAL, :FOLLOWME], [:NORMAL, :FORESIGHT], [:NORMAL, :GLARE], [:NORMAL, :GROWL], [:NORMAL, :GROWTH], [:NORMAL, :HAPPYHOUR], [:NORMAL, :HARDEN], [:NORMAL, :HEALBELL], [:NORMAL, :HELPINGHAND], [:NORMAL, :HOLDHANDS], [:NORMAL, :HOWL], [:NORMAL, :LASERFOCUS], [:NORMAL, :LEER], [:NORMAL, :LOCKON], [:NORMAL, :LOVELYKISS], [:NORMAL, :LUCKYCHANT], [:NORMAL, :MEFIRST], [:NORMAL, :MEANLOOK], [:NORMAL, :METRONOME], [:NORMAL, :MILKDRINK], [:NORMAL, :MIMIC], [:NORMAL, :MINDREADER], [:NORMAL, :MINIMIZE], [:NORMAL, :MORNINGSUN], [:NORMAL, :NATUREPOWER], [:NORMAL, :NOBLEROAR], [:NORMAL, :ODORSLEUTH], [:NORMAL, :PAINSPLIT], [:NORMAL, :PERISHSONG], [:NORMAL, :PLAYNICE], [:NORMAL, :PROTECT], [:NORMAL, :PSYCHUP], [:NORMAL, :RECOVER], [:NORMAL, :RECYCLE], [:NORMAL, :REFLECTTYPE], [:NORMAL, :REFRESH], [:NORMAL, :ROAR], [:NORMAL, :SAFEGUARD], [:NORMAL, :SCARYFACE], [:NORMAL, :SCREECH], [:NORMAL, :SHARPEN], [:NORMAL, :SHELLSMASH], [:NORMAL, :SIMPLEBEAM], [:NORMAL, :SING], [:NORMAL, :SKETCH], [:NORMAL, :SLACKOFF], [:NORMAL, :SLEEPTALK],
  [:NORMAL, :SMOKESCREEN],
  [:NORMAL, :SOFTBOILED], [:NORMAL, :SPLASH], [:NORMAL, :SPOTLIGHT], [:NORMAL, :STOCKPILE], [:NORMAL, :SUBSTITUTE], [:NORMAL, :SUPERSONIC], [:NORMAL, :SWAGGER], [:NORMAL, :SWALLOW], [:NORMAL, :SWEETSCENT], [:NORMAL, :SWORDSDANCE], [:NORMAL, :TAILWHIP], [:NORMAL, :TEARFULLOOK], [:NORMAL, :TEETERDANCE], [:NORMAL, :TICKLE], [:NORMAL, :TRANSFORM], [:NORMAL, :WHIRLWIND], [:NORMAL, :WISH], [:NORMAL, :WORKUP], [:NORMAL, :YAWN], [:POISON, :BELCH], [:POISON, :GUNKSHOT], [:POISON, :SLUDGEWAVE], [:POISON, :SLUDGEBOMB], [:POISON, :POISONJAB], [:POISON, :CROSSPOISON], [:POISON, :SLUDGE], [:POISON, :VENOSHOCK], [:POISON, :CLEARSMOG], [:POISON, :POISONFANG], [:POISON, :POISONTAIL], [:POISON, :ACID], [:POISON, :ACIDSPRAY], [:POISON, :SMOG], [:POISON, :POISONSTING], [:POISON, :ACIDARMOR], [:POISON, :BANEFULBUNKER], [:POISON, :COIL], [:POISON, :GASTROACID], [:POISON, :POISONGAS], [:POISON, :POISONPOWDER], [:POISON, :PURIFY], [:POISON, :TOXIC], [:POISON, :TOXICSPIKES], [:POISON, :TOXICTHREAD], [:POISON, :VENOMDRENCH], [:PSYCHIC, :PRISMATICLASER], [:PSYCHIC, :PSYCHOBOOST], [:PSYCHIC, :FUTURESIGHT], [:PSYCHIC, :SYNCHRONOISE], [:PSYCHIC, :DREAMEATER], [:PSYCHIC, :PHOTONGEYSER], [:PSYCHIC, :PSYSTRIKE], [:PSYCHIC, :PSYCHIC], [:PSYCHIC, :PSYCHICFANGS], [:PSYCHIC, :EXTRASENSORY], [:PSYCHIC, :HYPERSPACEHOLE], [:PSYCHIC, :PSYSHOCK], [:PSYCHIC, :ZENHEADBUTT], [:PSYCHIC, :LUSTERPURGE], [:PSYCHIC, :MISTBALL], [:PSYCHIC, :PSYCHOCUT], [:PSYCHIC, :PSYBEAM], [:PSYCHIC, :HEARTSTAMP], [:PSYCHIC, :CONFUSION], [:PSYCHIC, :STOREDPOWER], [:PSYCHIC, :MIRRORCOAT], [:PSYCHIC, :PSYWAVE], [:PSYCHIC, :AGILITY], [:PSYCHIC, :ALLYSWITCH], [:PSYCHIC, :AMNESIA], [:PSYCHIC, :BARRIER], [:PSYCHIC, :CALMMIND], [:PSYCHIC, :COSMICPOWER], [:PSYCHIC, :GRAVITY], [:PSYCHIC, :GUARDSPLIT], [:PSYCHIC, :GUARDSWAP], [:PSYCHIC, :HEALBLOCK], [:PSYCHIC, :HEALPULSE], [:PSYCHIC, :HEALINGWISH], [:PSYCHIC, :HEARTSWAP], [:PSYCHIC, :HYPNOSIS], [:PSYCHIC, :IMPRISON], [:PSYCHIC, :INSTRUCT], [:PSYCHIC, :KINESIS], [:PSYCHIC, :LIGHTSCREEN], [:PSYCHIC, :LUNARDANCE], [:PSYCHIC, :MAGICCOAT], [:PSYCHIC, :MAGICROOM], [:PSYCHIC, :MEDITATE], [:PSYCHIC, :MIRACLEEYE], [:PSYCHIC, :POWERSPLIT], [:PSYCHIC, :POWERSWAP], [:PSYCHIC, :POWERTRICK], [:PSYCHIC, :PSYCHICTERRAIN], [:PSYCHIC, :PSYCHOSHIFT], [:PSYCHIC, :REFLECT], [:PSYCHIC, :REST], [:PSYCHIC, :ROLEPLAY], [:PSYCHIC, :SKILLSWAP], [:PSYCHIC, :SPEEDSWAP], [:PSYCHIC, :TELEKINESIS], [:PSYCHIC, :TELEPORT], [:PSYCHIC, :TRICK], [:PSYCHIC, :TRICKROOM], [:PSYCHIC, :WONDERROOM], [:ROCK, :HEADSMASH], [:ROCK, :ROCKWRECKER], [:ROCK, :DIAMONDSTORM], [:ROCK, :STONEEDGE], [:ROCK, :POWERGEM], [:ROCK, :ROCKSLIDE], [:ROCK, :ANCIENTPOWER], [:ROCK, :ROCKTOMB], [:ROCK, :ROCKTHROW], [:ROCK, :SMACKDOWN], [:ROCK, :ACCELEROCK], [:ROCK, :ROLLOUT], [:ROCK, :ROCKBLAST], [:ROCK, :ROCKPOLISH], [:ROCK, :SANDSTORM], [:ROCK, :STEALTHROCK], [:ROCK, :WIDEGUARD], [:STEEL, :DOOMDESIRE], [:STEEL, :IRONTAIL], [:STEEL, :SUNSTEELSTRIKE], [:STEEL, :METEORMASH], [:STEEL, :ANCHORSHOT], [:STEEL, :FLASHCANNON], [:STEEL, :IRONHEAD], [:STEEL, :SMARTSTRIKE], [:STEEL, :STEELWING], [:STEEL, :DOUBLEIRONBASH], [:STEEL, :MIRRORSHOT], [:STEEL, :MAGNETBOMB], [:STEEL, :GEARGRIND], [:STEEL, :METALCLAW], [:STEEL, :BULLETPUNCH], [:STEEL, :GYROBALL], [:STEEL, :HEAVYSLAM], [:STEEL, :METALBURST], [:STEEL, :AUTOTOMIZE], [:STEEL, :GEARUP], [:STEEL, :IRONDEFENSE], [:STEEL, :KINGSSHIELD], [:STEEL, :METALSOUND], [:STEEL, :SHIFTGEAR], [:WATER, :HYDROCANNON], [:WATER, :WATERSPOUT], [:WATER, :HYDROPUMP], [:WATER, :ORIGINPULSE], [:WATER, :STEAMERUPTION], [:WATER, :CRABHAMMER], [:WATER, :AQUATAIL], [:WATER, :MUDDYWATER], [:WATER, :SPARKLINGARIA], [:WATER, :SURF], [:WATER, :LIQUIDATION], [:WATER, :DIVE], [:WATER, :SCALD], [:WATER, :WATERPLEDGE], [:WATER, :WATERFALL], [:WATER, :RAZORSHELL], [:WATER, :BRINE], [:WATER, :BUBBLEBEAM], [:WATER, :OCTAZOOKA], [:WATER, :WATERPULSE], [:WATER, :AQUAJET], [:WATER, :BUBBLE], [:WATER, :WATERGUN], [:WATER, :CLAMP],
  [:WATER, :WHIRLPOOL], [:WATER, :WATERSHURIKEN], [:WATER, :AQUARING], [:WATER, :RAINDANCE], [:WATER, :SOAK], [:WATER, :WATERSPORT], [:WATER, :WITHDRAW], [:DARK, :FAINTATTACK], [:NORMAL, :HIDDENPOWER2], [:NORMAL, :TRIATTACK2], [:QMARKS, :FAKEMOVE]]


def make_alpha(pokemon)

  return if pokemon == nil


  return if pokemon.alpha? == true
  pokemon.level = ((pokemon.level * 2) + 5).clamp(1, 100).round
  # pokemon.name += " A"
  ivs = pokemon.iv
  firstiv = ivs.keys.sample
  secondiv = ivs.keys.sample
  while firstiv == secondiv
    secondiv = ivs.keys.sample
  end
  pokemon.iv[firstiv] = 31
  pokemon.iv[secondiv] = 31
  pokemon.alpha = true
  items = [:LEFTOVERS,:ROCKYHELMET,:RAZORCLAW,:WIDELENS,:QUICKCLAW,:SITRUSBERRY,:ENIGMABERRY,:KINGSROCK,:WEAKNESSPOLICY,:FOCUSSASH,:ASSAULTVEST]
  customitems = [:ALPHABOND,:ALPHADEFENSE]
  items.shuffle!
  customitems.shuffle!
  pokemon.item = items[0]
  if rand(15) < 1
    pokemon.item = customitems[0]
  end
  learnable_moves = pokemon.getMoveList
  learnable_moves += pokemon.getMoveRelearnerList
  learnable_moves += pokemon.getEventMoveList
  species = pokemon.species_data

  species.get_evolutions(true).each do |evo|
    # [new_species, method, parameter, boolean]

    next if evo[3] # Prevolution
    poke = Pokemon.new(evo[0],100)
    learnable_moves += poke.getMoveList
    learnable_moves += poke.getMoveRelearnerList
    learnable_moves += poke.getEventMoveList
  end
  echoln learnable_moves.inspect
  move_list = ALL_MOVES.clone
  move_list.shuffle!
  blacklisted_moves = [
  :GROWL, :TACKLE, :LEER, :STRINGSHOT, :SCRATCH, :HEALPULSE, :EERIEIMPULSE, :SPLASH, :SWALLOW, :TAILWHIP,
  :REFLECTTYPE, :RECYCLE, :REFRESH, :SAFEGUARD, :SLEEPTALK, :LUCKYCHANT, :MEFIRST, :EXPLOSION, :SELFDESTRUCT,
  :HELPINGHAND, :MIRRORMOVE, :COPYCAT, :TRANSFORM, :METRONOME, :HARDEN, :SPOTLIGHT, :LASTRESORT, :PERISHSONG,
  :AFTERYOU, :ASSIST, :DESTINYBOND, :SPITUP, :FLING, :ELECTRIFY, :TRICKORTREAT, :TRICK, :SOAK, :BURNUP,
  :FAINTATTACK, :HIDDENPOWER2, :TRIATTACK2, :FAKEMOVE,:EMBER,:ABSORB,:WATERGUN
  
  :FORESIGHT, :ODORSLEUTH, :FOLLOWME, :ALLYSWITCH, :POWERTRICK, :ROLEPLAY, :INSTRUCT, :GUARDSPLIT,
  :POWERSPLIT, :GUARDSWAP, :MEDITATE


  moves = move_list.select { |key, _| key == pokemon.type1 and !learnable_moves.include?(_) and !pokemon.moves.include?(_) and !blacklisted_moves.include?(_)}[0, 3]
  moves += move_list.select { |key, _| key == pokemon.type2 and !learnable_moves.include?(_) and !pokemon.moves.include?(_) and !blacklisted_moves.include?(_)}[0, 3]
  moves.shuffle!
  if pokemon.moves.size() == 4
    pokemon.moves[0] = Pokemon::Move.new(moves[0][1])
  else
    pokemon.moves.push(Pokemon::Move.new(moves[0][1]))
  end
  if rand(30) < 1
    moves = move_list.select { |key, _| key == pokemon.type1 and !learnable_moves.include?(_) and !pokemon.moves.include?(_)}[0, 3]
    moves += move_list.select { |key, _| key == pokemon.type2 and !learnable_moves.include?(_) and !pokemon.moves.include?(_)}[0, 3]
    moves.shuffle!
    if pokemon.moves.size() == 4
      pokemon.moves[rand(2) + 1] = Pokemon::Move.new(moves[0][1])
    else
      pokemon.moves.push(Pokemon::Move.new(moves[0][1]))
    end
  end

end

