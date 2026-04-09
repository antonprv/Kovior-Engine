using System.Diagnostics;
using System.Threading;

namespace Sandbox;

public static partial class Networking
{
	private static volatile bool s_isClosing;
	private static readonly ManualResetEventSlim ShutdownEvent = new( false );

	internal static void StartThread()
	{
		s_isClosing = false;
		ShutdownEvent.Reset();

		var thread = new Thread( RunThread )
		{
			Name = "Networking (managed)",
			Priority = ThreadPriority.AboveNormal
		};

		thread.Start();
	}

	internal static void StopThread()
	{
		s_isClosing = true;
		ShutdownEvent.Set();
	}

	static readonly Lock NetworkThreadLock = new Lock();

	/// <summary>
	/// The target tick rate for the networking thread, updated from the main thread
	/// each frame to avoid thread safety issues with ProjectSettings.
	/// </summary>
	private static volatile int s_threadTickRate = 30;

	private static void RunThread()
	{
		try
		{
			var stopwatch = Stopwatch.StartNew();

			while ( !s_isClosing )
			{
				var system = System;

				if ( system is not null )
				{
					lock ( NetworkThreadLock )
					{
						system.ProcessMessagesInThread();
					}
				}

				var targetMs = 1000.0 / s_threadTickRate;
				var elapsed = stopwatch.Elapsed.TotalMilliseconds;

				stopwatch.Restart();

				var remainingMs = targetMs - elapsed;

				if ( remainingMs > 1.0 )
				{
					ShutdownEvent.Wait( (int)remainingMs );
				}
				else if ( remainingMs > 0 )
				{
					Thread.Yield();
				}
			}
		}
		catch ( Exception e )
		{
			Log.Error( e, "Network Thread Error" );
		}
	}
}
