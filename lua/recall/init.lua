local M = {
    history = {},
    config = {
        re_sort = true,
        initial_mode = "normal",
        layout_config = {
            prompt_position = "top",
            width = 0.5,
            height = 0.5,
        }
    },
}


function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)
end

-- Adds the current buffer to the file history.
function M.add_to_history()
    local bufname = vim.fn.expand('%:p') -- Get the full path of the current buffer
    if bufname == "" then return end -- Ignore empty buffers
    if vim.fn.filereadable(bufname) == 0 then return end -- Ignore non-readable buffers

    -- If the file is already in history, remove it
    for i, entry in ipairs(M.history) do
        if entry == bufname then
            if M.config.re_sort then
                table.remove(M.history, i)
                break
            end
            return
        end
    end

    table.insert(M.history, 1, bufname)
end

-- Function to open a file from the history by index
function M.open_file_from_history(index)
    if M.history[index] then
        vim.api.nvim_command("e " .. M.history[index])
    end
end

-- Function to remove a file from the history by index
function M.remove_file_from_history(index)
    if M.history[index] then
        table.remove(M.history, index)
    end
end

function M.recall()
    local finders = require "telescope.finders"
    local pickers = require "telescope.pickers"
    local actions = require "telescope.actions"
    local actions_state = require "telescope.actions.state"

    local function get_results()
        local items = {}
        for i, file in ipairs(M.history) do
            table.insert(items, { display = file, value = i })
        end
        return items
    end

    local function entry_maker(entry)
        return {
            display = entry.display,
            value = entry.value,
            ordinal = entry.display,
        }
    end

    pickers.new({}, {
        initial_mode = M.config.initial_mode,
        prompt_title = "Recall",
        results_title = "(d)elete",
        finder = finders.new_table {
            results = get_results(),
            entry_maker = entry_maker,
        },
        sorter = nil,
        sorting_strategy = "ascending",
        layout_config = M.config.layout_config,
        attach_mappings = function(_, map)
            map('n', '<CR>', function(prompt_bufnr)
                local selection = actions_state.get_selected_entry()
                actions.close(prompt_bufnr)
                M.open_file_from_history(selection.value)
            end)

            map('n', 'd', function(prompt_bufnr)
                local selection = actions_state.get_selected_entry()
                M.remove_file_from_history(selection.value)

                local picker = actions_state.get_current_picker(prompt_bufnr)
                picker:refresh(
                    finders.new_table {
                        results = get_results(),
                        entry_maker = entry_maker,
                    },
                    { reset_prompt = true }
                )
            end)
            return true
        end,
    }):find()
end

-- Autocommand to track file opening
vim.api.nvim_create_autocmd('BufEnter', {
    callback = function()
        M.add_to_history()
    end
})

-- Define commands to open the floating window, move back, and move forward
vim.api.nvim_create_user_command('Recall', function() M.recall() end, {})

return M
