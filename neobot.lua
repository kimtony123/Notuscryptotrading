local json = require("json")
local math = require("math")

-- Data storage
users = users or {}
balances = balances or {}
openTrades = openTrades or {}
archivedTrades = archivedTrades or {}

-- List to store closed checked trades
closedCheckedTrades = closedCheckedTrades or {}

-- Credentials token
NEO = "wPmY5MO0DPWpgUGGj8LD7ZmuPmWdYZ2NnELeXdGgctQ"


-- Function to deposit funds
function deposit(user, amount)
    if amount <= 0 then
        print("Deposit amount must be positive.")
        return
    end
    
    balances[user] = (balances[user] or 0) + amount
    print(user .. " deposited " .. amount .. ". New balance: " .. balances[user])
end

-- Function to withdraw funds
function withdraw(user, amount)
    if balances[user] and balances[user] >= amount then
        balances[user] = balances[user] - amount
        print(user .. " withdrew " .. amount .. ". New balance: " .. balances[user])
    else
        print("Insufficient balance for " .. user)
    end
end

-- Function to find the most successful trader
function findMostSuccessfulTrader()
    local wins = {}
    
    for _, trade in pairs(archivedTrades) do
        if trade.Outcome == "won" then
            wins[trade.UserId] = (wins[trade.UserId] or 0) + 1
        end
    end

    local maxWins = 0
    local mostSuccessfulTrader = nil
    
    for user, winCount in pairs(wins) do
        if winCount > maxWins then
            maxWins = winCount
            mostSuccessfulTrader = user
        end
    end
    
    return mostSuccessfulTrader
end


-- Callback function for fetch price
fetchPriceCallback = nil

function fetchPrice(callback)
    local url = BASE_URL

    Send({
        Target = _0RBT_TOKEN,
        Action = "Transfer",
        Recipient = _0RBIT,
        Quantity = FEE_AMOUNT,
        ["X-Url"] = url,
        ["X-Action"] = "Get-Real-Data"
    })

    print("GET Request sent to the 0rbit process.")

    -- Save the callback to be called later
    fetchPriceCallback = callback
end

function receiveData(msg)
    local res = json.decode(msg.Data)

    for i, coin in ipairs(res) do
        TOKEN_PRICES[coin.symbol] = {
            id = coin.id,
            name = coin.name,
            symbol = coin.symbol,
            current_price = coin.current_price
        }
    end

    -- Printing the filtered data for verification
    for symbol, coin in pairs(TOKEN_PRICES) do
        print("ID: " .. coin.id .. ", Name: " .. coin.name .. ", Symbol: " .. coin.symbol .. ", Current Price: " .. coin.current_price)
    end

    -- Call the callback if it exists
    if fetchPriceCallback then
        fetchPriceCallback()
        fetchPriceCallback = nil -- Clear the callback after calling
    end
end

function getTokenPrice(token)
    local token_data = TOKEN_PRICES[token]

    if not token_data or not token_data.current_price then
        return nil
    else
        return token_data.current_price
    end
end


-- Function to get current time
function getCurrentTime()
    return os.time()
end

-- Function to convert a table to a JSON string
function tableToJson(tbl)
    local result = {}
    for key, value in pairs(tbl) do
        local valueType = type(value)
        if valueType == "table" then
            value = tableToJson(value)
            table.insert(result, string.format('"%s":%s', key, value))
        elseif valueType == "string" then
            table.insert(result, string.format('"%s":"%s"', key, value))
        elseif valueType == "number" then
            table.insert(result, string.format('"%s":%d', key, value))
        elseif valueType == "function" then
            table.insert(result, string.format('"%s":"%s"', key, tostring(value)))
        end
    end

    local json = "{" .. table.concat(result, ",") .. "}"
    return json
end

-- Function to fetch openTrades from another process
function fetchOpenTrades()
    -- Send a request to the target process to get the openTrades
    ao.send({
        Target = NEO, -- Replace with the actual target process name or identifier
        Action = "getOpenTrades"
    })
end

-- Function to place a trade in the target process
function placeTradeInTargetProcess(tradeData)
    ao.send({
        Target = NEO, -- Replace NEO with the actual identifier of the target process
        Action = "trade",
        Tags = tradeData
    })
    print("Sent trade request to the target process with data:", json.encode(tradeData))
end


-- Function to replicate and execute a trade
function replicateAndExecuteTrade(msg, user, trade)
    if not trade then
        print("No trade to replicate")
        return
    end

    local currentPrice = getTokenPrice(trade.AssetId)

    if not currentPrice then
        print("Failed to fetch current price for asset " .. trade.AssetId)
        return
    end

    local contractType = currentPrice > tonumber(trade.AssetPrice) and "Put" or "Call"
   
    local newTrade = {
        UserId = user,
        TradeId = "Trade" .. os.time(),
        AssetId = trade.AssetId,
        AssetPrice = currentPrice,
        ContractType = contractType,
        ContractStatus = "open",
        CreatedTime = msg.Timestamp,
        ContractExpiry = msg.Timestamp + (trade.ContractExpiry - trade.CreatedTime),
        BetAmount = trade.BetAmount,
        Payout = trade.Payout
    }

    openTrades[newTrade.TradeId] = newTrade
    print("Replicated trade for user " .. user)

    -- Send the trade to the target process
    ao.send({
        Target = "NEO",  -- Replace NEO with the actual identifier of the target process
        Action = "trade",
        Tags = newTrade
    })
    print("Sent trade request to the target process with data:", json.encode(newTrade))

    -- Move the trade to closedTrades
    closedTrades[newTrade.TradeId] = newTrade
    openTrades[trade.TradeId] = nil
    print("Executed and moved trade to closedTrades")
end

-- Function to fetch openTrades from another process
function fetchOpenTrades()
    -- Send a request to the target process to get the openTrades
    ao.send({
        Target = "TargetProcess", -- Replace with the actual target process name or identifier
        Action = "getOpenTrades"
    })
end


Handlers.add(
     "fetchOpenTrades",
    Handlers.utils.hasMatchingTag("Action", "fetchOpenTrades"),
    fetchOpenTrades

)


-- Handler to request placing a trade in the target process
Handlers.add(
    "requestTrade",
    Handlers.utils.hasMatchingTag("Action", "requestTrade"),
    function(m)
        local tradeData = json.decode(m.Data)
        placeTradeInTargetProcess(tradeData)
    end
)

-- Handler to process the response with openTrades data
Handlers.add(
    "openTradesResponse",
    Handlers.utils.hasMatchingTag("Action", "openTradesResponse"),
    function(m)
        local openTradesData = json.decode(m.Data)
        print("Received openTrades data:", json.encode(openTradesData))
        
        -- Save the openTrades data into closedCheckedTrades list
        for _, trade in pairs(openTradesData) do
            table.insert(closedCheckedTrades, trade)
        end
        
        -- Replicate and execute each trade
        for _, trade in pairs(openTradesData) do
            replicateAndExecuteTrade(m, ao.id, trade)
        end
        
        print("Updated closedCheckedTrades:", json.encode(closedCheckedTrades))
    end
)

-- Example usage
fetchOpenTrades()

-- Handler to respond to openTrades request
Handlers.add(
    "getOpenTrades",
    Handlers.utils.hasMatchingTag("Action", "getOpenTrades"),
    function(m)
        -- Send the openTrades data back to the requesting process
        ao.send({
            Target = m.From, -- Reply to the sender
            Action = "openTradesResponse",
            Data = json.encode(openTrades)
        })
    end
)

-- Handler for deposit
Handlers.add(
    "deposit",
    Handlers.utils.hasMatchingTag("Action", "deposit"),
    function(m)
        local user = m.From
        local amount = tonumber(m.Data)
        deposit(user, amount)
    end
)

-- Handler for withdrawal
Handlers.add(
    "withdraw",
    Handlers.utils.hasMatchingTag("Action", "withdraw"),
    function(m)
        local user = m.From
        local amount = tonumber(m.Data)
        withdraw(user, amount)
    end
)

-- Handler to replicate the most successful trader's trade
Handlers.add(
    "replicateTrade",
    Handlers.utils.hasMatchingTag("Action", "replicateTrade"),
    function(m)
        local user = m.From
        local mostSuccessfulTrader = findMostSuccessfulTrader()
        if mostSuccessfulTrader then
            -- Find an open trade of the most successful trader
            for _, trade in pairs(openTrades) do
                if trade.UserId == mostSuccessfulTrader then
                    replicateAndExecuteTrade(user, trade)
                    break
                end
            end
        else
            print("No successful trader found to replicate")
        end
    end
)