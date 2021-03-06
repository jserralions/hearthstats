require 'httparty'
class CardImporter

  attr_reader :all_cards

  GOOD_TYPES = ["minion", "spell", "weapon"]

  def initialize()
    @all_cards = HTTParty.get("https://api.hearthstonejson.com/v1/latest/enUS/cards.collectible.json")
  end

  def import_set(set_name)
    @all_cards.each do |card|
      next if card["set"] != set_name
      next if !(GOOD_TYPES.include? card["type"].downcase)
      next if card["collectible"] != true
      db_card = Card.find_by_name(card["name"])
      returned_card = db_card
      if db_card.nil?
        returned_card = create_card(card)
      elsif db_card.blizz_id.length > card["id"].length
        returned_card = update_card(card, db_card)
      else
        returned_card = update_specs(card, db_card)
      end
      returned_card.update_attribute(:card_set, set_name)
    end
  end

  def import_all
    p @all_cards.size
    @all_cards.each do |card|
      next if !GOOD_TYPES.include? card["type"].downcase
      next if card["collectible"] != true
      db_card = Card.find_by_name(card["name"])
      returned_card = db_card
      if db_card.nil?
        returned_card = create_card(card)
      elsif db_card.blizz_id.length > card["id"].length
        returned_card = update_card(card, db_card)
      else
        returned_card = update_specs(card, db_card)
      end
      returned_card.update_attribute(:card_set, card["set"])
    end

    p "All Done"
  end

  def fix_missing_info
    all_cards_flat = @all_cards.to_a.flatten
    cards = Card.where{(rarity_id == nil) | (mana == nil)}
    messed = []
    cards.each do |card|
      proper_card = all_cards_flat.find {|set_card| set_card["name"] == card.name && GOOD_TYPES.include?(set_card["type"])}
      if proper_card.nil?
        messed << card
      else
        update_card(proper_card, card)
      end
    end

    messed
  end

  def patch_mechanics
    all_cards_flat = @all_cards.to_a.flatten
    fails = []
    Card.all.each do |card|
      proper_card = all_cards_flat.find {|set_card| set_card["name"] == card.name && GOOD_TYPES.include?(set_card["type"])}
      if proper_card.nil?
        fails << card.name
        next
      end
      add_mechanics(proper_card["mechanics"], card)
    end

    p fails.inspect
  end

  def scrape_images(set)
    require 'mechanize'
    agent = Mechanize.new
    Card.where(card_set: set).each do |card|
      begin
        link = "http://wow.zamimg.com/images/hearthstone/cards/enus/original/#{card.blizz_id}.png"
        agent.get(link).save_as "/Users/trigun0x2/Dropbox/Projects/newcards/#{set}/#{card.name.parameterize}.png"
      rescue
        puts card.name
      end
    end
    p "Big Bro, The job is done."
  end

  private

  def update_specs(card, card_db)
    rarities = Card::RARITY.invert
    klasses = Klass::LIST.invert
    unless card_db.update_attributes(
      attack: card["attack"],
      health: card["health"],
      type_name: card["type"].to_s,
      rarity_id: rarities[card["rarity"]].to_i,
      klass_id: klasses[card["playerClass"]].to_i,
      mana: card["cost"],
      collectible: card["collectible"]
    )
      Rails.logger.info(card_db.errors.messages.inspect)
    end

    add_mechanics(card["mechanics"], card_db)

    card_db
  end
  def update_card(card, card_db)
    rarities = Card::RARITY.invert
    klasses = Klass::LIST.invert
    params = {description: card["text"].to_s,
      attack: card["attack"],
      health: card["health"],
      type_name: card["type"].to_s,
      blizz_id: card["id"],
      rarity_id: rarities[card["rarity"]],
      klass_id: klasses[card["playerClass"]],
      mana: card["cost"],
      collectible: card["collectible"]}
    unless card_db.update_attributes(params)
      p card_db.errors.messages.inspect
    end

    card_db
  end

  def create_card(card)
    rarities = Card::RARITY.invert
    klasses = Klass::LIST.invert
    card_db = Card.create(
      name: card["name"].to_s,
      description: card["text"].to_s,
      attack: card["attack"],
      health: card["health"],
      type_name: card["type"].to_s,
      blizz_id: card["id"],
      rarity_id: rarities[card["rarity"]],
      klass_id: klasses[card["playerClass"]],
      mana: card["cost"],
      collectible: card["collectible"]
    )
    add_mechanics(card["mechanics"], card_db)

    card_db
  end

  def add_mechanics(mechanics, card)
    if mechanics
      new_mechs = mechanics - card.mechanics.pluck(:name)
      new_mechs.each do |mech|
        mech_db = Mechanic.find_by_name(mech)
        if mech_db.nil?
          mech_db = Mechanic.create(name: mech)
        end
        CardMechanic.create(card_id: card.id, mechanic_id: mech_db.id)
      end
    end
  end
end
