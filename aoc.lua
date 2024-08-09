local json = require("json")
local math = require("math")

-- Credentials token
 AOC = "pdKYJSk3n2XuFSt6AX-A7n_DhMmTWxCH3W8dxGBPXjM"

-- Table to track addresses that have requested tokens
RequestedAddresses = RequestedAddresses or {}


Trades = Trades or {}

local time = os.time()

print(time)
-- Because json.encode(Proposals) just returns [object Object] instead of a proper string, likely because
-- I am being a bit naughty and storing functions directly in that table in order to load them into Handlers.list
function tableToJson(tbl)
    local result = {}
    for key, value in pairs(tbl) do
        local valueType = type(value)
        if valueType == "table" then
            -- Recursive call for nested tables
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



-- Trade Handler Function
Handlers.add(
    "trade",
    Handlers.utils.hasMatchingTag("Action", "trade"),
    function(m)
        if m.Tags.TradeId and m.Tags.CreatedTime and m.Tags.Country and m.Tags.CountryId and m.Tags.CurrentTemp and m.Tags.ContractType
            and m.Tags.ContractStatus and m.Tags.ContractExpiry and m.Tags.BetAmount then

            -- Convert BetAmount to a number
            local qty = tonumber(m.Tags.BetAmount)

            -- Check if qty is nil and handle the error
            if qty == nil then
                print("Error: BetAmount is not a valid number.")
                ao.send({ Target = m.From, Data = "Invalid BetAmount. It must be a number." })
                return
            end

            -- Validate qty is a number
            assert(type(qty) == 'number', 'Quantity Tag must be a number')

            -- Check if qty is more than 1 and less than 200000
            if qty > 1 and qty < 200000000 then
                Balances[m.From] = Balances[m.From] - qty
                print("Transferred: " .. qty .. " successfully to " .. AOC)

                -- Create trade record
                Trades[m.Tags.TradeId] = {
                    Country = m.Tags.Country,
                    CountryId = m.Tags.CountryId,
                    CurrentTemp = m.Tags.CurrentTemp,
                    ContractType = m.Tags.ContractType,
                    ContractStatus = m.Tags.ContractStatus,
                    CreatedTime = m.Tags.CreatedTime,
                    ContractExpiry = m.Tags.ContractExpiry,
                    BetAmount = qty
                }

                -- Print the Trades table for debugging
                print("Trades table after update: " .. tableToJson(Trades))

                ao.send({ Target = m.From, Data = "Successfully Created Trade" })
            else
                -- Print error message for invalid quantity
                print("Invalid quantity: " .. qty .. ". Must be more than 1 and less than 200000.")
                ao.send({ Target = m.From, Data = "Invalid quantity. Must be more than 1 and less than 200000." })
            end
        else
            -- Print error message for missing tags
            print("Missing required tags for trade creation.")
            ao.send({ Target = m.From, Data = "Missing required tags for trade creation." })
        end
    end
)



-- RequestTokens Handler Function
Handlers.add(
    "RequestTokens",
    Handlers.utils.hasMatchingTag("Action", "RequestTokens"),
    function(Msg)
        local requesterAddress = Msg.From

        -- Check if the address has already requested tokens
        if RequestedAddresses[requesterAddress] then
            print("Address " .. requesterAddress .. " has already requested tokens.")
            ao.send({
                Target = requesterAddress,
                Action = "Message",
                Text = "You have already requested tokens. You cannot request again."
            })
        else
            -- Grant tokens and record the request
            local amount = 1000000
            ao.send({
                Target = AOC,
                Action = "Transfer",
                Quantity = tostring(amount),
                Recipient = requesterAddress,
            })
            print("Transferred: " .. amount .. " successfully to " .. requesterAddress)

            -- Record the address as having requested tokens
            RequestedAddresses[requesterAddress] = true

            -- Send a success message
            ao.send({
                Target = requesterAddress,
                Action = "Message",
                Text = "Tokens transferred successfully. You cannot request again."
            })
        end
    end
)

Handlers.add(
    "Trades",
    Handlers.utils.hasMatchingTag("Action", "Trades"),
    function(m)
        ao.send({ Target = m.From, Data = tableToJson(Trades) })
    end
)
