local json = require("json")
local math = require("math")

-- Credentials and game token
local NOT = "Fq4KbPbzALhTnb-jvq040o0Na7O5H6Q_Cn52YQ3ZBfI"

local GAME = "ajy8UC6fNHMuS-vAbfaDS9TvHsExe9FSZdGasyg2MKc"

local _0RBIT = "BaMK1dfayo75s3q1ow6AO64UDpD9SEFbeE8xYrY2fyQ"

local BASE_URL = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=false"

-- Data structures
---@type table
ReceivedData = ReceivedData or {}
---@type table
Trades = Trades or {}
---@type table
Winners = Winners or {}

-- Function to initialize the app
function initializeApp()
    Trades =  Trades or {}
    Winners = Trades or {}
    print("Options Trading App initialized.")
end

-- Function to transfer cred to start the game
---@param amount number
---@return nil
local function transferCred(amount)
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

-- Function to create a new trade
---@param contractExpiry number
---@param amount number
---@param contractType string
---@param assetName string
---@param assetId string
---@param assetPrice number
---@param payout number
---@return table
local function createTrade(contractExpiry, amount, contractType, assetName, assetId, assetPrice, payout)
    if amount <= 0 or amount >= 100 then
        print("Trade amount must be more than 0 and less than 100.")
        return nil
    end
    transferCred(amount)
    local tradeId = tostring(math.random(100000, 500000))
    local timeCreated = os.time()  -- Current time
    -- Minimum contract expiry is 1 minute
    local contractExpiryTime = os.time() + math.max(60, contractExpiry * 60)
    local contractExpiryRounded = math.floor((contractExpiryTime + 30) / 60) * 60  -- Round to the nearest minute

    local newTrade = {
        assetName = assetName,
        tradeId = tradeId,
        timeCreated = timeCreated,
        assetId = assetId,
        amount = amount,
        contractExpiry = contractExpiryRounded,
        contractType = contractType,
        assetPrice = assetPrice,
        payout = payout,
        status = "open"
    }
    Trades[tradeId] = newTrade
    print("New trade created: " .. tradeId)
    return newTrade
end

-- Function to check contract expiry and close positions
---@return nil
function checkContractExpiry()
    for tradeId, trade in pairs(Trades) do
        if os.time() >= trade.contractExpiry then
            print("Contract expired for trade: " .. tradeId)
            trade.status = "open"
            local currentAssetPrice = getAssetPriceAtExpiry(trade.contractExpiry, trade.assetId, trade.assetName)
            if currentAssetPrice then
                if isWinner(trade, currentAssetPrice) then
                    table.insert(Winners, trade)
                else
                    trade.status = "closed"
                    print("Trade " .. tradeId .. " is not a winner and has been closed.")
                end
            else
                print("No matching asset price found for expiry time.")
            end
        end
    end
end

-- Function to get the asset price at contract expiry
---@param expiryTime number
---@param assetId string
---@param assetName string
---@return number|nil
function getAssetPriceAtExpiry(expiryTime, assetId, assetName)
    for _, data in ipairs(ReceivedData) do
        if data.id == assetId and data.name == assetName then
            return data.current_price
        end
    end
    return nil  -- Return nil if no matching time is found
end

-- Function to determine if a trade is a winner
---@param trade table
---@param currentAssetPrice number
---@return boolean
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
---@return nil
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
        winner.status = "closed"
    end
    -- Clear winners list after sending rewards
    Winners = {}
end

-- Periodic check for contract expiry and sending rewards
---@return nil
function onTick()
    Send({
        Target = _0RBIT,
        Action = "Get-Real-Data",
        Url = BASE_URL
    })
    checkContractExpiry()
    sendRewards()
end

-- Schedule the Get-Request handler every minute
function scheduleGetRequest()
    while true do
        Send({
            Target = _0RBIT,
            Action = "Get-Real-Data",
            Url = BASE_URL
        })
        print("Scheduled GET Request to 0rbit process.")
        os.execute("sleep 60")  -- Wait for 60 seconds (1 minute)
    end
end

-- Define a pattern matching function
---@param action string
---@return function
local function hasAction(action)
    return function(msg)
        return msg.Action == action and 1 or 0
    end
end

-- Handlers
Handlers.add(
    "TradeRequest",
    hasAction("TradeRequest-complete"),
    function(msg)
    handleTradeRequest(msg)
end)

Handlers.add(
    "Get-Request",
    hasAction("Sponsored-Get-Request"),
    function(msg)
        Send({
            Target = _0RBIT,
            Action = "Get-Real-Data",
            Url = BASE_URL
        })
        print("You have sent a GET Request to the 0rbit process.")
    end
)

Handlers.add(
    "Receive-Data",
    hasAction("Receive-Response"),
    function(msg)
        local res = json.decode(msg.Data)
        ReceivedData = res
        print("You have received the data from the 0rbit process.")
    end
)

Handlers.add(
    "RequestTokens",
    hasAction("RequestTokens-now"),
    function(msg)
        local amount = 10
        print("Transferring Tokens: " .. amount)
        ao.send({
            Target = NOT,
            Action = "Transfer",
            Quantity = tostring(amount),
            Recipient = msg.From,
        })
        Send({
            Target = msg.From,
            Action = "Message",
            Text = "You have received " .. amount .. " tokens."
        })
    end
)

-- New handler to access trades with contract details
Handlers.add(
    "AccessTrades",
    hasAction("AccessTrades-list"),
    function(msg)
        local tradeDetails = {}
        for tradeId, trade in pairs(Trades) do
            table.insert(tradeDetails, trade)
        end
        Send({
            Target = NOT,
            Action = "Message",
        })
        Send({
            Target = msg.From,
            Action = "Message",
            Text = "Current trades: " .. json.encode(tradeDetails)
        })
    end
)

-- Initialize the application
initializeApp()

-- Test trade creation (can be adjusted or removed later)
local testTrade = createTrade(1, 50, "Call", "Bitcoin", "bitcoin", 40000, 0.2)  -- Create a test trade with 1-minute expiry