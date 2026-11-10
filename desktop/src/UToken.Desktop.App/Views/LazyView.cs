using Avalonia;
using Avalonia.Controls;
using Avalonia.Threading;

namespace UToken.Desktop.App.Views;

/// <summary>
/// Giữ chỗ cho một view: chỉ tạo view thật khi lần đầu hiện ra (hoặc khi <see cref="WarmUpAll"/> chạy lúc rảnh).
/// MainWindow chứa 13 view ẩn/hiện theo trang; tạo hết lúc mở cửa sổ làm khởi động chậm.
/// </summary>
public sealed class LazyView : Decorator
{
    public static readonly StyledProperty<Type?> ViewTypeProperty =
        AvaloniaProperty.Register<LazyView, Type?>(nameof(ViewType));

    public Type? ViewType
    {
        get => GetValue(ViewTypeProperty);
        set => SetValue(ViewTypeProperty, value);
    }

    public bool IsCreated => Child is not null;

    protected override void OnPropertyChanged(AvaloniaPropertyChangedEventArgs change)
    {
        base.OnPropertyChanged(change);
        if ((change.Property == IsVisibleProperty || change.Property == ViewTypeProperty) && IsVisible) Create();
    }

    public void Create()
    {
        if (Child is null && ViewType is not null) Child = (Control)Activator.CreateInstance(ViewType)!;
    }

    /// <summary>Tạo dần các view còn lại ở mức ưu tiên thấp, mỗi lượt một view, để không chặn thao tác của người dùng.</summary>
    public static void WarmUpAll(IEnumerable<LazyView> views)
    {
        var queue = new Queue<LazyView>(views.Where(v => !v.IsCreated));
        void Next()
        {
            if (queue.Count == 0) return;
            queue.Dequeue().Create();
            Dispatcher.UIThread.Post(Next, DispatcherPriority.Background);
        }
        Dispatcher.UIThread.Post(Next, DispatcherPriority.Background);
    }
}
