local json = require("json")
local math = require("math")


-- Credentials and game token
local NOT = "Fq4KbPbzALhTnb-jvq040o0Na7O5H6Q_Cn52YQ3ZBfI"
local GAME = "ajy8UC6fNHMuS-vAbfaDS9TvHsExe9FSZdGasyg2MKc"

 
_0RBIT = "BaMK1dfayo75s3q1ow6AO64UDpD9SEFbeE8xYrY2fyQ"
 
BASE_URL = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=false"
 
ReceivedData = ReceivedData or {}
Trades = Trades or {}
Winners = Winners or {}
NOW = NOW or nil

    -- Function to initialize the app
    function initializeApp()
    Trades = {}
    Winners = {}
    print("Options Trading App initialized.")
    end

    -- Function to create a new trade
    local function createTrade(amount, contractType,assetName,assetId,assetPrice,payout)
    if amount <= 0 then
        print("Trade amount must be higher than 0.")
        return
    end

    if amount > 100 then
        print("Trade amount must be lower than 100.")
        return
    end
    local assetName = assetName
    local tradeId = tostring(math.random(100000, 500000))
    local timeCreated = NOW
    local assetId = assetId
    local currentAssetPrice = assetPrice
    local payout = payout
    local contractType = contractType
    local contractExpiry = timeCreated + 86400  -- Set contract expiry exactly one day from timeCreated

    local newTrade = {
        assetName = assetName,
        tradeId = tradeId,
        timeCreated = timeCreated,
        assetId = assetId,
        amount = amount,
        contractExpiry = contractExpiry,
        contractType = contractType,
        assetPrice = currentAssetPrice,
        status = "open"
    }
    Trades[tradeId] = newTrade
    print("New trade created: " .. tradeId)
    end

    --Function to check contract expiry and close positions
    function checkContractExpiry()
        for tradeId, trade in pairs(Trades) do
            if os.time() >= trade.contractExpiry then
                print("Contract expired for trade: " .. tradeId)
                trade.status = "closed"
                local currentAssetPrice = getAssetPriceAtExpiry(trade.contractExpiry)
                if isWinner(trade, currentAssetPrice) then
                    table.insert(Winners, trade)
                end
            end
        end
    end
    
    -- Function to get the asset price at contract expiry
    function getAssetPriceAtExpiry(expiryTime)
        for _, hourData in ipairs(OutcomeData.hours) do
            if hourData.datetimeEpoch == expiryTime then
                return hourData.temp
            end
        end
        return nil -- Return nil if no matching time is found
    end
    
    -- Function to determine if a trade is a winner
    function isWinner(trade, currentAssetPrice)
        if trade.contractType == "Call" and currentAssetPrice > trade.assetPrice then
            return true
        elseif trade.contractType == "Put" and currentAssetPrice < trade.assetPrice then
            return true
        else
            return false
        end
    end
    
    -- Function to send rewards to winners
    function sendRewards()
        for _, winner in ipairs(Winners) do
            local payout = winner.amount * (1 + winner.payout)
            ao.send({
                Target = PaymentToken,
                Action = "Transfer",
                Quantity = tostring(payout),
                Recipient = winner,
                Reason = reason
            })

            print("Sending reward: " .. payout .. " to trade: " .. winner.tradeId)
            -- Placeholder for reward sending logic
        end
        -- Clear winners list after sending rewards
        Winners = {}
    end



   -- Function to transfer cred to start the game
   local function transferCred()
    -- Send command to transfer cred to game
        local response = Send({Target = NOT
        , Action = "Transfer", 
        Quantity = "10",
         Recipient = GAME})
        if response.status ~= "success" then
        -- Gunakan operator 'or' untuk menggantikan nilai nil dengan 'Unknown error'
        print("Error during credit transfer: " .. (response.error or "Unknown error"))
        else
        print("Credit transfer successful.")
    end
    end

     -- Check if player has enough cred to start the game
     local function checkPlayerCred()
        -- Assuming the player has enough cred, initiate the transfer and start the game
        transferCred()
        startGame()
        -- Print in green color
        print(colors.green .. "The game has started!" .. colors.reset)
    end

    -- Call function to check player's cred and start the game
    checkPlayerCred()

    -- Periodic check for contract expiry and sending rewards
    function onTick()
    -- Ensure OutcomeData is updated before checking contract expiry
        Send({
        Target = _0RBIT,
        Action = "Get-Real-Data",
        Url = BASE_URL_OUTCOME
            })

        -- Use current time and asset price from OutcomeData for checking contract expiry
        checkContractExpiry()
        sendRewards()
        end




-- Handlers
Handlers.add(
    "TradeRequest",
    Handlers.utils.hasMatchingTag("Action", "TradeRequest"),
    handleTradeRequest
)

Handlers.add(
    "Get-Request",
    Handlers.utils.hasMatchingTag("Action", "Sponsored-Get-Request"),
    function(msg)
        Send({
            Target = _0RBIT,
            Action = "Get-Real-Data",
            Url = BASE_URL
        })
        print(Colors.green .. "You have sent a GET Request to the 0rbit process.")
    end
)

Handlers.add(
    "Receive-Data",
    Handlers.utils.hasMatchingTag("Action", "Receive-Response"),
    function(msg)
        local res = json.decode(msg.Data)
        ReceivedData = res
        print(Colors.green .. "You have received the data from the 0rbit process.")
    end
)

Handlers.add(
    "RequestTokens",
    Handlers.utils.hasMatchingTag("Action", "RequestTokens"),
    function (Msg)
        print("Transfering Tokens: " .. tostring(math.floor(10000 * UNIT)))
        ao.send({
            Target = ao.id,
            Action = "Transfer",
            Quantity = tostring(math.floor(10)),
            Recipient = Msg.From,
        })
    end
)

