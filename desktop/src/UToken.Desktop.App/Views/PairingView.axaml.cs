using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.VisualTree;
using UToken.Desktop.App.ViewModels;

namespace UToken.Desktop.App.Views;

public partial class PairingView : UserControl
{
    private bool _updating;
    public PairingView() => InitializeComponent();

    private void DigitChanged(object? sender, TextChangedEventArgs e)
    {
        if (_updating || sender is not TextBox box || box.DataContext is not PairingDigit digit ||
            DataContext is not MainViewModel vm) return;
        var index = Array.IndexOf(vm.PairingDigits, digit);
        if (index < 0) return;
        var text = new string((box.Text ?? "").Where(c => c >= '0' && c <= '9').ToArray());
        _updating = true;
        try
        {
            if (text.Length > 1)
            {
                var start = text.Length == 6 ? 0 : index;
                for (var i = 0; i < text.Length && start + i < 6; i++)
                    vm.PairingDigits[start + i].Text = text[i].ToString();
                box.Text = vm.PairingDigits[index].Text;
                FocusDigit(Math.Min(5, start + text.Length));
            }
            else
            {
                digit.Text = text; box.Text = text;
                if (text.Length == 1) FocusDigit(Math.Min(5, index + 1));
            }
        }
        finally { _updating = false; }
    }

    private void DigitKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key != Key.Back || sender is not TextBox box || !string.IsNullOrEmpty(box.Text) ||
            DataContext is not MainViewModel vm || box.DataContext is not PairingDigit digit) return;
        FocusDigit(Math.Max(0, Array.IndexOf(vm.PairingDigits, digit) - 1));
    }

    private void FocusDigit(int index)
    {
        var boxes = this.GetVisualDescendants().OfType<TextBox>().ToArray();
        if (index < boxes.Length) { boxes[index].Focus(); boxes[index].SelectAll(); }
    }
}
