local json = require("json")
local math = require("math")

-- Credentials and game token
local NOT = "Fq4KbPbzALhTnb-jvq040o0Na7O5H6Q_Cn52YQ3ZBfI"
local GAME = "ajy8UC6fNHMuS-vAbfaDS9TvHsExe9FSZdGasyg2MKc"

_0RBIT = "BaMK1dfayo75s3q1ow6AO64UDpD9SEFbeE8xYrY2fyQ"

BASE_URL = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=false"

ReceivedData = ReceivedData or {}
Trades = {}
Winners = {}
NOW = NOW or os.time()

-- Function to initialize the app
function initializeApp()
    Trades = {}
    Winners = {}
    print("Options Trading App initialized.")
end

-- Function to create a new trade
local function createTrade(contractExpiry , amount, contractType, assetName, assetId, assetPrice, payout)
    if amount <= 0 or amount >= 100 then
        print("Trade amount must be more than 0 and less than 100.")
        return
    end

    -- Function to transfer cred to start the game
    local function transferCred()
        local response = Send({
            Target = NOT,
            Action = "Transfer",
            Quantity = tostring(amount),
            Recipient = GAME
        })
        if response.status ~= "success" then
            print("Error during credit transfer: " .. (response.error or "Unknown error"))
        else
            print("Credit transfer successful.")
        end
    end

    local tradeId = tostring(math.random(100000, 500000))
    local timeCreated = math.floor(NOW / 3600) * 3600  -- Round to the nearest hour
    local contractExpiry = (NOW + 3600) + (contractExpiry *3600)  -- Ensure minimum expiry of 1 hour

    local newTrade = {
        assetName = assetName,
        tradeId = tradeId,
        timeCreated = timeCreated,
        assetId = assetId,
        amount = amount,
        contractExpiry = contractExpiry,
        contractType = contractType,
        assetPrice = assetPrice,
        payout = payout,
        status = "open"
    }
    Trades[tradeId] = newTrade
    print("New trade created: " .. tradeId)
end

-- Function to check contract expiry and close positions
function checkContractExpiry()
    for tradeId, trade in pairs(Trades) do
        if os.time() >= trade.contractExpiry then  -- Ensure at least one hour past expiry
            print("Contract expired for trade: " .. tradeId)
            trade.status = "closed"
            local currentAssetPrice = getAssetPriceAtExpiry(trade.contractExpiry, trade.assetId, trade.assetName)
            if currentAssetPrice then
                if isWinner(trade, currentAssetPrice) then
                    table.insert(Winners, trade)
                end
            else
                print("No matching asset price found for expiry time.")
            end
        end
    end
end

-- Function to get the asset price at contract expiry
function getAssetPriceAtExpiry(expiryTime, assetId, assetName)
    for _, data in ipairs(ReceivedData) do
        if data.id == assetId and data.name == assetName then
            return data.current_price
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
        local payout = winner.amount * (winner.payout + 1)
        ao.send({
            Target = NOT,
            Action = "Transfer",
            Quantity = tostring(payout),
            Recipient = winner,
            Reason = "Winning payout"
        })
        print("Sending reward: " .. payout .. " to trade: " .. winner.tradeId)
    end
    -- Clear winners list after sending rewards
    Winners = {}
end

-- Periodic check for contract expiry and sending rewards
function onTick()
    Send({
        Target = _0RBIT,
        Action = "Get-Real-Data",
        Url = BASE_URL
    })
    checkContractExpiry()
    sendRewards()
end

-- Handlers
Handlers.add("TradeRequest", Handlers.utils.hasMatchingTag("Action", "TradeRequest"), handleTradeRequest)

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
    function(Msg)
        print("Transferring Tokens: " .. tostring(math.floor(10000 * UNIT)))
        ao.send({
            Target = ao.id,
            Action = "Transfer",
            Quantity = tostring(math.floor(10)),
            Recipient = Msg.From,
        })
        Send({
            Target = msg.From,
            Action = "Message",
            Text = "You have received " .. amount .. " tokens."
        })
    end
)

-- Test trade creation (can be adjusted or removed later)
createTrade(50, "Call", "Bitcoin", "bitcoin", 40000, 0.2)
