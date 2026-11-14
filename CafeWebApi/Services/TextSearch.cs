using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace CafeWebApi.Services;

public static partial class TextSearch
{
    public static string Normalize(string value)
    {
        var lower = value.ToLowerInvariant().Replace('đ', 'd').Normalize(NormalizationForm.FormD);
        var result = new StringBuilder(lower.Length);
        foreach (var rune in lower.EnumerateRunes())
        {
            if (Rune.GetUnicodeCategory(rune) != UnicodeCategory.NonSpacingMark)
                result.Append(rune);
        }

        return Whitespace().Replace(result.ToString().Trim(), " ");
    }

    [GeneratedRegex(@"\s+")]
    private static partial Regex Whitespace();
}
