using Avalonia;
using Avalonia.Animation;
using Avalonia.Animation.Easings;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Styling;
using Avalonia.VisualTree;
using UToken.Desktop.App.Services;

namespace UToken.Desktop.App.Views;

/// <summary>
/// Phản hồi khi bấm cho mọi Button (gồm ToggleSwitch): nảy nhẹ (co rồi bật về) lúc nhấn và tiếng tick khi Click.
/// Dùng animation chạy bằng code thay vì Transitions trong style: Transitions qua Setter bị kẹt ở Avalonia 11.3.
/// Chỉ đổi RenderTransform nên không đo lại layout.
/// </summary>
public static class PressFeedback
{
    private static readonly Animation Bounce = Make(0.95);
    private static readonly Animation SoftBounce = Make(0.985); // thẻ lớn, mục thanh bên
    private static readonly AttachedProperty<CancellationTokenSource?> RunningProperty =
        AvaloniaProperty.RegisterAttached<Button, Button, CancellationTokenSource?>("PressFeedbackRunning");

    private static Animation Make(double scale) => new()
    {
        Duration = TimeSpan.FromMilliseconds(220),
        Easing = new CubicEaseOut(),
        Children = { Frame(0, 1), Frame(0.35, scale), Frame(1, 1) },
    };

    private static KeyFrame Frame(double cue, double scale) => new()
    {
        Cue = new Cue(cue),
        Setters = { new Setter(ScaleTransform.ScaleXProperty, scale), new Setter(ScaleTransform.ScaleYProperty, scale) },
    };

    private static bool _installed;

    public static void Install()
    {
        if (_installed) return;
        _installed = true;
        // Class handler nhận sender = phần tử bị bấm trúng (chữ/icon bên trong nút), nên tìm Button chứa nó.
        // handledEventsToo: Button tự đánh dấu PointerPressed là đã xử lý.
        InputElement.PointerPressedEvent.AddClassHandler<InputElement>((source, e) =>
        {
            if (source is Visual v && (v as Button ?? v.FindAncestorOfType<Button>()) is { } button) OnPressed(button, e);
        }, RoutingStrategies.Bubble, handledEventsToo: true);
        Button.ClickEvent.AddClassHandler<Button>((_, _) => ClickSound.Play(), RoutingStrategies.Bubble, handledEventsToo: true);
    }

    private static void OnPressed(Button button, PointerPressedEventArgs e)
    {
        if (!button.IsEffectivelyEnabled || !e.GetCurrentPoint(button).Properties.IsLeftButtonPressed) return;
        button.GetValue(RunningProperty)?.Cancel();
        var cts = new CancellationTokenSource();
        button.SetValue(RunningProperty, cts);
        var animation = button.Classes.Contains("source") || button.Classes.Contains("nav") || button is ToggleSwitch ? SoftBounce : Bounce;
        // ScaleTransform riêng, gán local: ScaleX/ScaleY là double nên có animator sẵn (RenderTransform thì không).
        // Transition RenderTransform của Fluent (ưu tiên Animation, cao hơn local) bị tắt trong App.axaml.
        if (button.RenderTransform is not ScaleTransform scale) button.RenderTransform = scale = new ScaleTransform();
        try { _ = animation.RunAsync(button, cts.Token); }
        catch (InvalidOperationException) { } // hiệu ứng là phụ: không bao giờ được làm hỏng cú bấm
    }
}
