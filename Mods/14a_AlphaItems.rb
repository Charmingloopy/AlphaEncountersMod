

## Custom Items
module AlphaItems
    START_ID_NUMBER = 8000
    @registered = false
    ITEMS = [
        { sym: :ALPHABOND},{ sym: :ALPHADEFENSE},
        ]
    def self.registrar
        if defined?(GameData::Item) && GameData::Item.respond_to?(:register)
            return [:gamedata_item, GameData::Item]
        end
        if defined?(Item) && Item.respond_to?(:register)
            return [:item_alias, Item]
        end
        nil
    end

    # Sanity-check that required systems exist before attempting registration.
    # Ensures MessageTypes and GameData::Item helpers exist, and that a registrar API was found.
    def self.ready?
        return false unless defined?(MessageTypes) && MessageTypes.respond_to?(:set)
        return false unless defined?(GameData::Item) && GameData::Item.respond_to?(:each) &&
                        GameData::Item.respond_to?(:exists?) && GameData::Item.respond_to?(:get)
        !!registrar
    end
    def self.register_one(reg_mod, sym, id_number, name, price, desc)
        plural = name + "s"
        reg_mod.register({
                          :id          => sym,
                          :id_number   => id_number,
                          :name        => name,
                          :name_plural => plural,
                          :pocket      => 1,
                          :price       => price,
                          :description => desc,
                          :field_use   => 0,
                          :battle_use  => 0,
                          :type        => 0,
                          :move        => nil
                         })
        MessageTypes.set(MessageTypes::Items,            id_number, name)
        MessageTypes.set(MessageTypes::ItemPlurals,      id_number, plural)
        MessageTypes.set(MessageTypes::ItemDescriptions, id_number, desc)
    end
    def self.used_id_numbers
        used = {}
        begin
            GameData::Item.each do |it|
                n = nil
                begin
                    n = it.id_number
                rescue
                    n = nil
                end
                used[n] = true if n.is_a?(Integer)
            end
        rescue
        end
        used
    end

    # Register all stones from STONES into GameData exactly once per game boot.
    # Skips if the item already exists, chooses free id_numbers starting from START_ID_NUMBER, and logs each decision.
    def self.register_once!
        return if @registered == true

        api = registrar

        return unless ready?
        api_name, reg_mod = api

        begin
            used = used_id_numbers
            numbers = []
            id_here = START_ID_NUMBER

            ITEMS.each do |s|
                sym   = s[:sym]
                name  = s[:name]  || s[:sym].to_s
                desc  = s[:desc]  || ""
                price = s[:price] || 0

                exists = false
                begin
                    exists = GameData::Item.exists?(sym)
                rescue
                    exists = false
                end

                if exists
                    it = nil
                    begin
                        it = GameData::Item.get(sym)
                    rescue
                        it = nil
                    end

                    next
                end

                id_here += 1 while used[id_here]
                numbers.push(id_here)
                used[id_here] = true

                register_one(reg_mod, sym, id_here, name, price, desc)


                id_here += 1
            end
            echoln numbers
            @registered = true
        rescue => e
            MegaStonesLog.err(e, "MegaStoneItems.register_once! (api=#{api.inspect})")

        end
    end
    @hooked = false

    # If the game exposes GameData.kurayeggs_loadsystem, hook it to run registration + icon copying after the data load completes.
    # This is a safer "run after core data is ready" point in some Kuray/KIF builds.
    def self.try_hook_kuray!
        return if @hooked
        return unless defined?(GameData)
        return unless GameData.respond_to?(:kurayeggs_loadsystem)


        begin
            sc = GameData.singleton_class
            unless sc.method_defined?(:__alpha_kurayeggs_loadsystem)
                sc.class_eval do
                    alias_method :__alpha_kurayeggs_loadsystem, :kurayeggs_loadsystem
                    define_method(:kurayeggs_loadsystem) do |*args|
                        __alpha_kurayeggs_loadsystem(*args)
                        self.register_once!

                    end
                end
            end
            @hooked = true

        rescue => e
            MegaStonesLog.err(e, "try_hook_kuray!")
        end
    end

    # Periodic bootstrap entry-point (called every Graphics.update).
    # Ensures the hooks/registration/icons/patches are installed, then runs one-time helpers (debug dump, self-fusion equip).
    def self.tick!
        self.try_hook_kuray!
        self.register_once!
        self.install_icon_fallback_hook!
    rescue => e
        MegaStonesLog.err(e, "MegaStoneBootstrap.tick!")
    end

    @hooked_icon = false

    def self.install_icon_fallback_hook!
        return if @hooked_icon

        begin
            if Kernel.private_method_defined?(:pbItemIconFile)
                Kernel.module_eval do
                    alias __megastones_orig_pbItemIconFile pbItemIconFile

                    # Hooked item icon resolver: falls back to Graphics/Items/<item_symbol> when the original pbItemIconFile result does not exist.
                    # This helps custom-registered stones show icons even if the engine's default lookup fails.
                    def pbItemIconFile(item)
                        f = __megastones_orig_pbItemIconFile(item)

                        begin
                            if f && MegaStoneIcons.resolve_exists?(f)
                                return f
                            end
                        rescue
                        end

                        sym = MegaStoneIcons.normalize_item_symbol(item)
                        if sym
                            alt = MegaStoneIcons.icon_path_no_ext_for(sym)
                            begin
                                return alt if MegaStoneIcons.resolve_exists?(alt)
                            rescue
                            end
                        end

                        f
                    end
                end

                MegaStonesLog.log("Installed pbItemIconFile fallback hook.")
                @hooked_icon = true
            end
        rescue => e
            MegaStonesLog.err(e, "MegaStoneIcons.install_icon_fallback_hook!")
        end
    end



end
if defined?(Graphics) && Graphics.respond_to?(:update)
    class << Graphics
        alias __alpha_boot_updat update
        # Graphics.update hook: calls the original Graphics.update, then runs MegaStoneBootstrap.tick! once per frame.
        # This makes the mod self-initializing without requiring manual calls elsewhere.
        def update(*args)
            __alpha_boot_updat(*args)
            AlphaItems.tick!
        end
    end
end

# parental bond item
#=======
# The maximum number of hits in a round this move will actually perform. This
# can be 1 for Beat Up, and can be 2 for any moves affected by Parental Bond.

class PokeBattle_Move
    def pbNumHits(user,targets)
        if user.hasActiveAbility?(:PARENTALBOND) && pbDamagingMove? &&
                    !chargingTurnMove? && targets.length==1 or user.item_id == :ALPHABOND && pbDamagingMove? &&
                    !chargingTurnMove? && targets.length==1
            # Record that Parental Bond applies, to weaken the second attack
            user.effects[PBEffects::ParentalBond] = 3
            return 2
        end
        return 1
    end

def pbReduceDamage(user,target)
    damage = target.damageState.calcDamage
    if target.item_id == :ALPHADEFENSE
        damage /= 1.05
    end
    # Substitute takes the damage
    if target.damageState.substitute
        damage = target.effects[PBEffects::Substitute] if damage>target.effects[PBEffects::Substitute]
        target.damageState.hpLost       = damage
        target.damageState.totalHPLost += damage
        return
    end
    # Disguise takes the damage
    return if target.damageState.disguise
    # Target takes the damage
    if damage>=target.hp
        damage = target.hp
        # Survive a lethal hit with 1 HP effects
        if nonLethal?(user,target)
            damage -= 1
        elsif target.effects[PBEffects::Endure]
            target.damageState.endured = true
            damage -= 1
        elsif damage==target.totalhp
            if target.hasActiveAbility?(:STURDY) && !@battle.moldBreaker
                target.damageState.sturdy = true
                damage -= 1
            elsif target.hasActiveItem?(:FOCUSSASH) && target.hp==target.totalhp
                target.damageState.focusSash = true
                damage -= 1
            elsif target.hasActiveItem?(:FOCUSBAND) && @battle.pbRandom(100)<10
                target.damageState.focusBand = true
                damage -= 1
            end
        end
    end
    damage = 0 if damage<0
    target.damageState.hpLost       = damage
    target.damageState.totalHPLost += damage
end
end
BattleHandlers::ItemOnSwitchIn.add(:ALPHABOND,
                                   proc { |item,battler,battle|
                                          battle.pbDisplay(_INTL("{1} bonds with its rage!",
                                                                 battler.pbThis))
                                        }
                                  )
BattleHandlers::ItemOnSwitchIn.add(:ALPHADEFENSE,
                                   proc { |item,battler,battle|
                                          battle.pbDisplay(_INTL("{1}'s aura protects them, they take 5% less damage!",
                                                                 battler.pbThis))
                                        }
                                  )
DebugMenuCommands.register("fillbag", {
                                       "parent"      => "itemsmenu",
                                       "name"        => _INTL("Fill Bag"),
                                       "description" => _INTL("Add a certain number of every item to the Bag."),
                                       "effect"      => proc {
                                                              params = ChooseNumberParams.new
                                                             params.setRange(1, Settings::BAG_MAX_PER_SLOT)
                                                             params.setInitialValue(1)
                                                             params.setCancelValue(0)
                                                             qty = pbMessageChooseNumber(_INTL("Choose the number of items."), params)
                                                             if qty > 0
                                                             GameData::Item.each { |i|
                                                                            if AlphaItems::ITEMS.include?(i.id)
                                                                                 next
                                                                                 end
                                                                            $PokemonBag.pbStoreItem(i.id, qty)
                                                                                 }
                                                             pbMessage(_INTL("The Bag was filled with {1} of each item.", qty))
                                                             end
                                                             }
                                      })
