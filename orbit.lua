local json = require("json")

_0RBIT = "BaMK1dfayo75s3q1ow6AO64UDpD9SEFbeE8xYrY2fyQ"
_0RBT_TOKEN = "BUhZLMwQ6yZHguLtJYA5lLUa9LQzLXMXRfaq9FVcPJc"

BASE_URL = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=false&locale=en"
FEE_AMOUNT = "1000000000000" -- 1 $0RBT

TOKEN_PRICES = TOKEN_PRICES or {}

function fetchPrice()
    local url = BASE_URL

    Send({
        Target = _0RBT_TOKEN,
        Action = "Transfer",
        Recipient = _0RBIT,
        Quantity = FEE_AMOUNT,
        ["X-Url"] = url,
        ["X-Action"] = "Get-Real-Data"
    })
    print(Colors.green .. "GET Request sent to the 0rbit process.")
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
end

function getTokenPrice(msg)
    local token = msg.Tags.Token
    local token_data = TOKEN_PRICES[token]

    if not token_data or not token_data.current_price then
        Handlers.utils.reply("Price not available!!!")(msg)
    else
        Handlers.utils.reply("Current Price: " .. tostring(token_data.current_price))(msg)
    end
end

Handlers.add(
    "GetTokenPrice",
    Handlers.utils.hasMatchingTag("Action", "Get-Token-Price"),
    getTokenPrice
)

Handlers.add(
    "FetchPrice",
    Handlers.utils.hasMatchingTag("Action", "Fetch-Price"),
    fetchPrice
)

Handlers.add(
    "ReceiveData",
    Handlers.utils.hasMatchingTag("Action", "Receive-Response"),
    receiveData
)
