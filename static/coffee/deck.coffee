# ===========================================================================
#
# deck.coffee
#
# Contains the view, model, and collection class definitions for the deck 
#
# ===========================================================================
#Get deck from text input
DECKVIZ.Deck.getDeckFromInput = (params) =>
    #Parses a decklist and returns a deck object with Key: Value of CardName:
    #   CardAmount
    #Parameters (either are optional, but at least one must be passed):
    #   el: specify the input element to get the deckText from
    #   deckText: string containing the deck text
    if not params
        return false

    #Setup params
    params = params || {}

    #Get deckText either from passed in element oer passed in deckText
    if params.el
        #Set a defaulty element
        deckText = el.val()
    if params.deckText
        deckText = params.deckText

    #Split the lines
    console.log(deckText)
    deckArray = deckText.split('\n')

    #Setup deck we'll return
    deck = {}

    #For each line in the deck text, add it to the deck object
    for cardText in deckArray
        #Get the number of cards
        #   Replace any non number or space characters.  Whatever number is
        #   found first will be parsed as the number of times this card is
        #   in the deck. e.g., "10 Forest" will get parsed as 10
        numCards = parseInt(cardText.replace(/[^0-9 ]/gi, ''), 10)

        #Replace the leading number and space with nothing
        #   e.g., "10 Forest" becomes "Forest"
        cardName = cardText.replace(/[0-9]+ */gi, '')

        #update the deck
        deck[cardName] = numCards

    return deck

#Setup deck to change on keyup
$('#deck').on('keyup', (e)=>
    DECKVIZ.Deck.create(DECKVIZ.Deck.getDeckFromInput({deckText: $('#deck').val()}))
)
# ===========================================================================
#
# Create deck
#
# ===========================================================================
DECKVIZ.Deck.create = (deck)=>
    #Takes in a deck parameter, which is an array of cards
    if not deck
        #Sample deck
        deck = {
            "Tamiyo, the Moon Sage": 2,
            "Entreat the Angels": 3,
            "Terminus": 4,
            "Lingering Souls": 4,
            "Isolated Chapel": 1,
            "Spellskite": 1,
            "Dismember": 3,
            "Pristine Talisman": 4,
            "White Sun's Zenith": 1,
            "Seachrome Coast": 4,
            "Gideon Jura": 3,
            "Day of Judgment": 2,
            "Glacial Fortress": 4,
            "Drowned Catacomb": 4,
            "Oblivion Ring": 3,
            "Think Twice": 4,
            "Ghost Quarter": 4,
            "Swamp": 1,
            "Island": 3,
            "Plains": 5
        }

        #Another test
        deck = {
            "Mutilate": 4,
            "Liliana's Shade": 3,
            "Murder": 3,
            "Killing Wave": 4,
            "Demonic Taskmaster": 3,
            "Swamp": 23,
            "Nefarox, Overlord of Grixis": 2,
            "Homicidal Seclusion": 2,
            "Duress": 4,
            "Appetite for Brains": 3,
            "Death Wind": 4,
            "Shimian Specter": 2,
            "Essence Harvest": 3
        }


    #Construct call to get cards from DB
    #store names of each card, which we'll join by a |
    urlArray = []
    for cardName, num of deck
        urlArray.push('^' + cardName + '$')
 
    #Setup the url with the cards passed in
    url = '/items/name=' + urlArray.join('|')

    #This will be the final deck object, an array of
    #   card objects
    finalDeck = []

    #Make the call
    $.ajax({
        url: url
        success: (res)=>
            #res is the response from the server, which contains an array 
            #   of cards
            #For each card returned, append it to the finalDeck X times
            #   where X is the number of items in the deck
            for card in res.cards
                #add the card X times
                for i in [0..deck[card.name]-1]
                    finalDeck.push(card)

            #Setup deck with proper number of cards
            DECKVIZ.Deck.manaCurve(finalDeck, deck)
    })

#========================================
#Create deck viz
#========================================
DECKVIZ.Deck.manaCurve= (deck, originalDeck)=>
    $('#svg-el').empty()

    #get width and height
    width = $('#svg-el').attr('width')
    height = $('#svg-el').attr('height')
    
    #Store reference to convertedManaCost function which calculates the
    #   converted mana cost
    calcCC = DECKVIZ.util.convertedManaCost

    #Build a dict of mana costs: number of cards with that cost
    manaCostLookup = {}

    tmpDeck = []

    #Copy deck into new array / get null mana cost spells out
    for card in deck
        if manaCostLookup[calcCC(card.manacost)]
            manaCostLookup[calcCC(card.manacost)] += 1
        else
            manaCostLookup[calcCC(card.manacost)] = 1
        if card.manacost
            tmpDeck.push(card)
    
    #Store original deck with lands
    completeDeck = _.clone(deck)

    #reassign deck, point to the original deck that contains cards
    #   which have null manacost (e.g., land)
    deck = tmpDeck

    #turn manaCostLookup into array
    manaCostArray = []
    #Setup array to have [cost, number of cards]
    for cost, num of manaCostLookup
        costInt = parseInt(cost, 10)
        if costInt
            manaCostArray.push([costInt, num])

    #Create a bar chart for mana curve
    xScale = d3.scale.linear()
        #Goes from 0 to the highest mana cost
        .domain([0, 9])
        .range([0, width])


    originalHeight = height
    height = height - 100

    yScale = d3.scale.linear()
        #Goes from 0 to the highest occurence of cards with that mana cost
        .domain([0, 60])
        .rangeRound([0, height])

    chart = d3.select('#svg-el')
        .selectAll("rect")
        .data(manaCostArray)
        .enter()
        
    chart.append("rect")
        .attr("x", (d, i) =>
            return xScale(d[0]) - .5
        )
        .attr("y", (d) =>
            cost = calcCC(d.manacost)
            return height - yScale(d[1]) - .5
        )
        .attr("width", (d,i)=>
            return width/(manaCostArray.length*2)
        )
        .attr("height", (d)=>
            cost = calcCC(d.manacost)
            return yScale(d[1]) - .5
        ).style("fill", (d,i) =>
            return DECKVIZ.util.colorScale['X']
        )

    chart.append("text")
        .attr("x", (d,i)=>
            return (xScale(d[0]) - .5) + (width/(manaCostArray.length*2)/2)
        ).attr("y", height + 20)
        .text((d,i)=>
            return d[0]
        )

    #bottom x axis
    d3.select('#svg-el').append("line")
        .attr("x1", 0)
        .attr("x2", width)
        .attr("y1", height - .5)
        .attr("y2", height - .5)
        .style("stroke", "#000")

    return true